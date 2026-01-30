package websocket

import (
	"sync"

	"github.com/rs/zerolog/log"
)

// Room represents a signaling room where peers can communicate
type Room struct {
	ID      string
	clients map[string]*Client
	mu      sync.RWMutex
}

// NewRoom creates a new Room
func NewRoom(id string) *Room {
	return &Room{
		ID:      id,
		clients: make(map[string]*Client),
	}
}

// AddClient adds a client to the room
func (r *Room) AddClient(client *Client) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.clients[client.ID] = client
}

// RemoveClient removes a client from the room
func (r *Room) RemoveClient(clientID string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.clients, clientID)
}

// GetClient gets a client by ID
func (r *Room) GetClient(clientID string) (*Client, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	client, ok := r.clients[clientID]
	return client, ok
}

// GetClients returns all clients in the room
func (r *Room) GetClients() []*Client {
	r.mu.RLock()
	defer r.mu.RUnlock()
	clients := make([]*Client, 0, len(r.clients))
	for _, c := range r.clients {
		clients = append(clients, c)
	}
	return clients
}

// GetPeers returns all clients as Peer structs (excluding the given ID)
func (r *Room) GetPeers(excludeID string) []Peer {
	r.mu.RLock()
	defer r.mu.RUnlock()
	peers := make([]Peer, 0, len(r.clients))
	for _, c := range r.clients {
		if c.ID != excludeID {
			peers = append(peers, c.ToPeer())
		}
	}
	return peers
}

// IsEmpty returns true if the room has no clients
func (r *Room) IsEmpty() bool {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return len(r.clients) == 0
}

// JoinRoomRequest is a request to join a room
type JoinRoomRequest struct {
	Client *Client
	RoomID string
}

// LeaveRoomRequest is a request to leave a room
type LeaveRoomRequest struct {
	Client *Client
	RoomID string
}

// ForwardRequest is a request to forward a message to a specific peer
type ForwardRequest struct {
	From     *Client
	TargetID string
	MsgType  MessageType
	Data     interface{}
}

// BroadcastRequest is a request to broadcast a message to all peers in a room
type BroadcastRequest struct {
	RoomID     string
	ExcludeIDs []string
	MsgType    MessageType
	Data       interface{}
}

// Hub maintains the set of active clients and rooms, and broadcasts messages
type Hub struct {
	// Registered clients
	clients map[string]*Client

	// Rooms for group communication
	rooms map[string]*Room

	// Channel for registering clients
	register chan *Client

	// Channel for unregistering clients
	unregister chan *Client

	// Channel for joining rooms
	joinRoom chan *JoinRoomRequest

	// Channel for leaving rooms
	leaveRoom chan *LeaveRoomRequest

	// Channel for forwarding messages to specific peers
	forwardToPeer chan *ForwardRequest

	// Channel for broadcasting to rooms
	broadcastToRoom chan *BroadcastRequest

	// Mutex for thread-safe access
	mu sync.RWMutex
}

// NewHub creates a new Hub
func NewHub() *Hub {
	return &Hub{
		clients:         make(map[string]*Client),
		rooms:           make(map[string]*Room),
		register:        make(chan *Client),
		unregister:      make(chan *Client),
		joinRoom:        make(chan *JoinRoomRequest),
		leaveRoom:       make(chan *LeaveRoomRequest),
		forwardToPeer:   make(chan *ForwardRequest),
		broadcastToRoom: make(chan *BroadcastRequest),
	}
}

// Run starts the hub's main event loop
func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.handleRegister(client)

		case client := <-h.unregister:
			h.handleUnregister(client)

		case req := <-h.joinRoom:
			h.handleJoinRoom(req)

		case req := <-h.leaveRoom:
			h.handleLeaveRoom(req)

		case req := <-h.forwardToPeer:
			h.handleForwardToPeer(req)

		case req := <-h.broadcastToRoom:
			h.handleBroadcastToRoom(req)
		}
	}
}

// handleRegister registers a new client
func (h *Hub) handleRegister(client *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	h.clients[client.ID] = client
	log.Info().
		Str("clientID", client.ID).
		Str("userID", client.UserID).
		Int("totalClients", len(h.clients)).
		Msg("Client registered")
}

// handleUnregister unregisters a client and removes from any rooms
func (h *Hub) handleUnregister(client *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if _, ok := h.clients[client.ID]; !ok {
		return
	}

	// Remove from current room if any
	roomID := client.GetRoomID()
	if roomID != "" {
		if room, ok := h.rooms[roomID]; ok {
			room.RemoveClient(client.ID)

			// Notify other peers in the room
			h.broadcastToRoomUnlocked(roomID, []string{client.ID}, MsgPeerLeft, PeerLeftData{
				RoomID: roomID,
				PeerID: client.ID,
			})

			// Clean up empty rooms
			if room.IsEmpty() {
				delete(h.rooms, roomID)
				log.Info().Str("roomID", roomID).Msg("Room removed (empty)")
			}
		}
	}

	close(client.send)
	delete(h.clients, client.ID)

	log.Info().
		Str("clientID", client.ID).
		Int("totalClients", len(h.clients)).
		Msg("Client unregistered")
}

// handleJoinRoom adds a client to a room
func (h *Hub) handleJoinRoom(req *JoinRoomRequest) {
	h.mu.Lock()
	defer h.mu.Unlock()

	client := req.Client
	roomID := req.RoomID

	// Leave current room if in one
	currentRoom := client.GetRoomID()
	if currentRoom != "" && currentRoom != roomID {
		if room, ok := h.rooms[currentRoom]; ok {
			room.RemoveClient(client.ID)

			// Notify peers in old room
			h.broadcastToRoomUnlocked(currentRoom, []string{client.ID}, MsgPeerLeft, PeerLeftData{
				RoomID: currentRoom,
				PeerID: client.ID,
			})

			// Clean up empty rooms
			if room.IsEmpty() {
				delete(h.rooms, currentRoom)
				log.Info().Str("roomID", currentRoom).Msg("Room removed (empty)")
			}
		}
	}

	// Get or create the room
	room, ok := h.rooms[roomID]
	if !ok {
		room = NewRoom(roomID)
		h.rooms[roomID] = room
		log.Info().Str("roomID", roomID).Msg("Room created")
	}

	// Get existing peers before adding new client
	existingPeers := room.GetPeers("")

	// Add client to room
	room.AddClient(client)
	client.SetRoomID(roomID)

	// Send list of existing peers to the joining client
	peersMsg, err := NewMessage(MsgPeers, PeersData{
		RoomID: roomID,
		Peers:  existingPeers,
	})
	if err == nil {
		client.SendMessage(peersMsg)
	}

	// Notify existing peers about the new client
	h.broadcastToRoomUnlocked(roomID, []string{client.ID}, MsgPeerJoined, PeerJoinedData{
		RoomID: roomID,
		Peer:   client.ToPeer(),
	})

	log.Info().
		Str("clientID", client.ID).
		Str("roomID", roomID).
		Int("peersInRoom", len(existingPeers)+1).
		Msg("Client joined room")
}

// handleLeaveRoom removes a client from a room
func (h *Hub) handleLeaveRoom(req *LeaveRoomRequest) {
	h.mu.Lock()
	defer h.mu.Unlock()

	client := req.Client
	roomID := req.RoomID

	room, ok := h.rooms[roomID]
	if !ok {
		return
	}

	room.RemoveClient(client.ID)
	client.SetRoomID("")

	// Notify other peers
	h.broadcastToRoomUnlocked(roomID, []string{client.ID}, MsgPeerLeft, PeerLeftData{
		RoomID: roomID,
		PeerID: client.ID,
	})

	// Clean up empty rooms
	if room.IsEmpty() {
		delete(h.rooms, roomID)
		log.Info().Str("roomID", roomID).Msg("Room removed (empty)")
	}

	log.Info().
		Str("clientID", client.ID).
		Str("roomID", roomID).
		Msg("Client left room")
}

// handleForwardToPeer forwards a message to a specific peer
func (h *Hub) handleForwardToPeer(req *ForwardRequest) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	// Find the target client - first check if they're in the same room
	roomID := req.From.GetRoomID()
	if roomID == "" {
		log.Warn().
			Str("fromID", req.From.ID).
			Str("targetID", req.TargetID).
			Msg("Cannot forward: sender not in a room")
		return
	}

	room, ok := h.rooms[roomID]
	if !ok {
		log.Warn().
			Str("roomID", roomID).
			Msg("Room not found")
		return
	}

	target, ok := room.GetClient(req.TargetID)
	if !ok {
		log.Warn().
			Str("targetID", req.TargetID).
			Str("roomID", roomID).
			Msg("Target peer not found in room")
		return
	}

	msg, err := NewMessage(req.MsgType, req.Data)
	if err != nil {
		log.Error().Err(err).Msg("Failed to create forward message")
		return
	}

	target.SendMessage(msg)
}

// handleBroadcastToRoom broadcasts a message to all clients in a room
func (h *Hub) handleBroadcastToRoom(req *BroadcastRequest) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	h.broadcastToRoomUnlocked(req.RoomID, req.ExcludeIDs, req.MsgType, req.Data)
}

// broadcastToRoomUnlocked broadcasts to a room (caller must hold lock)
func (h *Hub) broadcastToRoomUnlocked(roomID string, excludeIDs []string, msgType MessageType, data interface{}) {
	room, ok := h.rooms[roomID]
	if !ok {
		return
	}

	excludeSet := make(map[string]bool)
	for _, id := range excludeIDs {
		excludeSet[id] = true
	}

	msg, err := NewMessage(msgType, data)
	if err != nil {
		log.Error().Err(err).Msg("Failed to create broadcast message")
		return
	}

	for _, client := range room.GetClients() {
		if !excludeSet[client.ID] {
			client.SendMessage(msg)
		}
	}
}

// GetClient returns a client by ID
func (h *Hub) GetClient(clientID string) (*Client, bool) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	client, ok := h.clients[clientID]
	return client, ok
}

// GetRoom returns a room by ID
func (h *Hub) GetRoom(roomID string) (*Room, bool) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	room, ok := h.rooms[roomID]
	return room, ok
}

// Stats returns hub statistics
func (h *Hub) Stats() (clients int, rooms int) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients), len(h.rooms)
}

// Register registers a new client with the hub
func (h *Hub) Register(client *Client) {
	h.register <- client
}

// Unregister unregisters a client from the hub
func (h *Hub) Unregister(client *Client) {
	h.unregister <- client
}
