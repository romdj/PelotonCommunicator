package websocket

import (
	"encoding/json"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"github.com/rs/zerolog/log"
)

const (
	// Time allowed to write a message to the peer
	writeWait = 10 * time.Second

	// Time allowed to read the next pong message from the peer
	pongWait = 60 * time.Second

	// Send pings to peer with this period (must be less than pongWait)
	pingPeriod = (pongWait * 9) / 10

	// Maximum message size allowed from peer
	maxMessageSize = 65536
)

// Client represents a WebSocket client connection
type Client struct {
	ID         string
	UserID     string
	DeviceInfo string
	RoomID     string
	hub        *Hub
	conn       *websocket.Conn
	send       chan []byte
	mu         sync.RWMutex
}

// NewClient creates a new WebSocket client
func NewClient(id, userID, deviceInfo string, hub *Hub, conn *websocket.Conn) *Client {
	return &Client{
		ID:         id,
		UserID:     userID,
		DeviceInfo: deviceInfo,
		hub:        hub,
		conn:       conn,
		send:       make(chan []byte, 256),
	}
}

// GetRoomID returns the client's current room ID
func (c *Client) GetRoomID() string {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.RoomID
}

// SetRoomID sets the client's current room ID
func (c *Client) SetRoomID(roomID string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.RoomID = roomID
}

// ReadPump pumps messages from the WebSocket connection to the hub
func (c *Client) ReadPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	c.conn.SetReadLimit(maxMessageSize)
	c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Error().Err(err).Str("clientID", c.ID).Msg("WebSocket read error")
			}
			break
		}

		// Parse the message
		var msg Message
		if err := json.Unmarshal(message, &msg); err != nil {
			log.Error().Err(err).Str("clientID", c.ID).Msg("Failed to parse message")
			c.sendError("invalid_message", "Failed to parse message")
			continue
		}

		// Handle the message
		c.handleMessage(&msg)
	}
}

// WritePump pumps messages from the hub to the WebSocket connection
func (c *Client) WritePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				// The hub closed the channel
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)

			if err := w.Close(); err != nil {
				return
			}
		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// handleMessage processes incoming WebSocket messages
func (c *Client) handleMessage(msg *Message) {
	switch msg.Type {
	case MsgJoinRoom:
		c.handleJoinRoom(msg)
	case MsgLeaveRoom:
		c.handleLeaveRoom(msg)
	case MsgOffer:
		c.handleOffer(msg)
	case MsgAnswer:
		c.handleAnswer(msg)
	case MsgCandidate:
		c.handleCandidate(msg)
	case MsgPTTStart:
		c.handlePTTStart(msg)
	case MsgPTTEnd:
		c.handlePTTEnd(msg)
	default:
		log.Warn().Str("type", string(msg.Type)).Str("clientID", c.ID).Msg("Unknown message type")
		c.sendError("unknown_type", "Unknown message type: "+string(msg.Type))
	}
}

// handleJoinRoom processes a join room request
func (c *Client) handleJoinRoom(msg *Message) {
	var data JoinRoomData
	if err := msg.ParseData(&data); err != nil {
		c.sendError("invalid_data", "Invalid join room data")
		return
	}

	// For MVP, we use a hardcoded room - no auth required
	// In Phase 2, we'll validate room membership via Group Service
	if data.RoomID == "" {
		data.RoomID = "default" // MVP: default room for testing
	}

	c.hub.joinRoom <- &JoinRoomRequest{
		Client: c,
		RoomID: data.RoomID,
	}

	log.Info().
		Str("clientID", c.ID).
		Str("userID", c.UserID).
		Str("roomID", data.RoomID).
		Msg("Client joining room")
}

// handleLeaveRoom processes a leave room request
func (c *Client) handleLeaveRoom(msg *Message) {
	var data LeaveRoomData
	if err := msg.ParseData(&data); err != nil {
		c.sendError("invalid_data", "Invalid leave room data")
		return
	}

	roomID := data.RoomID
	if roomID == "" {
		roomID = c.GetRoomID()
	}

	if roomID != "" {
		c.hub.leaveRoom <- &LeaveRoomRequest{
			Client: c,
			RoomID: roomID,
		}
	}
}

// handleOffer forwards a WebRTC offer to the target peer
func (c *Client) handleOffer(msg *Message) {
	var data OfferData
	if err := msg.ParseData(&data); err != nil {
		c.sendError("invalid_data", "Invalid offer data")
		return
	}

	// Set the from field to this client's ID
	data.From = c.ID

	c.hub.forwardToPeer <- &ForwardRequest{
		From:     c,
		TargetID: data.To,
		MsgType:  MsgOffer,
		Data:     data,
	}

	log.Debug().
		Str("from", c.ID).
		Str("to", data.To).
		Str("sessionID", data.SessionID).
		Msg("Forwarding offer")
}

// handleAnswer forwards a WebRTC answer to the target peer
func (c *Client) handleAnswer(msg *Message) {
	var data AnswerData
	if err := msg.ParseData(&data); err != nil {
		c.sendError("invalid_data", "Invalid answer data")
		return
	}

	// Set the from field to this client's ID
	data.From = c.ID

	c.hub.forwardToPeer <- &ForwardRequest{
		From:     c,
		TargetID: data.To,
		MsgType:  MsgAnswer,
		Data:     data,
	}

	log.Debug().
		Str("from", c.ID).
		Str("to", data.To).
		Str("sessionID", data.SessionID).
		Msg("Forwarding answer")
}

// handleCandidate forwards an ICE candidate to the target peer
func (c *Client) handleCandidate(msg *Message) {
	var data CandidateData
	if err := msg.ParseData(&data); err != nil {
		c.sendError("invalid_data", "Invalid candidate data")
		return
	}

	// Set the from field to this client's ID
	data.From = c.ID

	c.hub.forwardToPeer <- &ForwardRequest{
		From:     c,
		TargetID: data.To,
		MsgType:  MsgCandidate,
		Data:     data,
	}

	log.Debug().
		Str("from", c.ID).
		Str("to", data.To).
		Msg("Forwarding ICE candidate")
}

// handlePTTStart broadcasts that this client started talking
func (c *Client) handlePTTStart(msg *Message) {
	roomID := c.GetRoomID()
	if roomID == "" {
		c.sendError("not_in_room", "You must join a room first")
		return
	}

	c.hub.broadcastToRoom <- &BroadcastRequest{
		RoomID:     roomID,
		ExcludeIDs: []string{c.ID},
		MsgType:    MsgPeerTalking,
		Data: PeerTalkingData{
			RoomID:    roomID,
			PeerID:    c.ID,
			IsTalking: true,
		},
	}

	log.Debug().
		Str("clientID", c.ID).
		Str("roomID", roomID).
		Msg("PTT started")
}

// handlePTTEnd broadcasts that this client stopped talking
func (c *Client) handlePTTEnd(msg *Message) {
	roomID := c.GetRoomID()
	if roomID == "" {
		c.sendError("not_in_room", "You must join a room first")
		return
	}

	c.hub.broadcastToRoom <- &BroadcastRequest{
		RoomID:     roomID,
		ExcludeIDs: []string{c.ID},
		MsgType:    MsgPeerTalking,
		Data: PeerTalkingData{
			RoomID:    roomID,
			PeerID:    c.ID,
			IsTalking: false,
		},
	}

	log.Debug().
		Str("clientID", c.ID).
		Str("roomID", roomID).
		Msg("PTT ended")
}

// sendError sends an error message to the client
func (c *Client) sendError(code, message string) {
	errMsg, err := NewMessage(MsgError, ErrorData{
		Code:    code,
		Message: message,
	})
	if err != nil {
		log.Error().Err(err).Msg("Failed to create error message")
		return
	}

	c.SendMessage(errMsg)
}

// SendMessage sends a message to the client
func (c *Client) SendMessage(msg *Message) {
	data, err := json.Marshal(msg)
	if err != nil {
		log.Error().Err(err).Msg("Failed to marshal message")
		return
	}

	select {
	case c.send <- data:
	default:
		log.Warn().Str("clientID", c.ID).Msg("Client send buffer full, dropping message")
	}
}

// ToPeer converts the client to a Peer struct
func (c *Client) ToPeer() Peer {
	return NewPeer(c.ID, c.UserID, c.DeviceInfo)
}
