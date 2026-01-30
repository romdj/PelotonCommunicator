package websocket

import (
	"encoding/json"
	"time"
)

// MessageType defines the type of WebSocket message
type MessageType string

const (
	// Client -> Server messages
	MsgJoinRoom   MessageType = "join_room"
	MsgLeaveRoom  MessageType = "leave_room"
	MsgOffer      MessageType = "offer"
	MsgAnswer     MessageType = "answer"
	MsgCandidate  MessageType = "candidate"
	MsgPTTStart   MessageType = "ptt_start"
	MsgPTTEnd     MessageType = "ptt_end"

	// Server -> Client messages
	MsgPeers       MessageType = "peers"
	MsgPeerJoined  MessageType = "peer_joined"
	MsgPeerLeft    MessageType = "peer_left"
	MsgPeerTalking MessageType = "peer_talking"
	MsgError       MessageType = "error"
)

// Message is the base message structure for all WebSocket communication
type Message struct {
	Type MessageType     `json:"type"`
	Data json.RawMessage `json:"data"`
}

// JoinRoomData is sent when a client wants to join a signaling room
type JoinRoomData struct {
	RoomID     string `json:"roomId"`
	UserID     string `json:"userId"`
	DeviceInfo string `json:"deviceInfo,omitempty"`
}

// LeaveRoomData is sent when a client wants to leave a room
type LeaveRoomData struct {
	RoomID string `json:"roomId"`
}

// Peer represents information about a connected peer
type Peer struct {
	ID         string `json:"id"`
	UserID     string `json:"userId"`
	DeviceInfo string `json:"deviceInfo,omitempty"`
	JoinedAt   int64  `json:"joinedAt"`
}

// PeersData is sent to a client when they join a room, listing all current peers
type PeersData struct {
	RoomID string `json:"roomId"`
	Peers  []Peer `json:"peers"`
}

// PeerJoinedData is broadcast when a new peer joins the room
type PeerJoinedData struct {
	RoomID string `json:"roomId"`
	Peer   Peer   `json:"peer"`
}

// PeerLeftData is broadcast when a peer leaves the room
type PeerLeftData struct {
	RoomID string `json:"roomId"`
	PeerID string `json:"peerId"`
}

// OfferData contains WebRTC SDP offer
type OfferData struct {
	From        string            `json:"from"`
	To          string            `json:"to"`
	SessionID   string            `json:"sessionId"`
	Description SDPDescription    `json:"description"`
}

// AnswerData contains WebRTC SDP answer
type AnswerData struct {
	From        string            `json:"from"`
	To          string            `json:"to"`
	SessionID   string            `json:"sessionId"`
	Description SDPDescription    `json:"description"`
}

// SDPDescription represents WebRTC SDP
type SDPDescription struct {
	Type string `json:"type"` // "offer" or "answer"
	SDP  string `json:"sdp"`
}

// CandidateData contains ICE candidate information
type CandidateData struct {
	From      string       `json:"from"`
	To        string       `json:"to"`
	SessionID string       `json:"sessionId"`
	Candidate ICECandidate `json:"candidate"`
}

// ICECandidate represents a WebRTC ICE candidate
type ICECandidate struct {
	Candidate     string `json:"candidate"`
	SDPMid        string `json:"sdpMid"`
	SDPMLineIndex int    `json:"sdpMLineIndex"`
}

// PTTStartData is sent when a user starts transmitting
type PTTStartData struct {
	RoomID string `json:"roomId"`
}

// PTTEndData is sent when a user stops transmitting
type PTTEndData struct {
	RoomID string `json:"roomId"`
}

// PeerTalkingData is broadcast to notify others that a peer is talking
type PeerTalkingData struct {
	RoomID   string `json:"roomId"`
	PeerID   string `json:"peerId"`
	IsTalking bool  `json:"isTalking"`
}

// ErrorData is sent when an error occurs
type ErrorData struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// NewMessage creates a new message with the given type and data
func NewMessage(msgType MessageType, data interface{}) (*Message, error) {
	jsonData, err := json.Marshal(data)
	if err != nil {
		return nil, err
	}
	return &Message{
		Type: msgType,
		Data: jsonData,
	}, nil
}

// ParseData parses the message data into the provided struct
func (m *Message) ParseData(v interface{}) error {
	return json.Unmarshal(m.Data, v)
}

// NewPeer creates a new Peer with the current timestamp
func NewPeer(id, userID, deviceInfo string) Peer {
	return Peer{
		ID:         id,
		UserID:     userID,
		DeviceInfo: deviceInfo,
		JoinedAt:   time.Now().Unix(),
	}
}
