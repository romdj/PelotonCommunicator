package websocket

import (
	"encoding/json"
	"testing"
	"time"
)

// These tests drive the hub's handlers directly (no Run loop, no network) so each
// routing rule is checked in isolation. End-to-end behaviour over real WebSocket
// connections lives in cmd/main_integration_test.go.

func newTestClient(hub *Hub, id string) *Client {
	return NewClient(id, "user-"+id, "test-device", hub, nil)
}

func registered(hub *Hub, ids ...string) []*Client {
	clients := make([]*Client, 0, len(ids))
	for _, id := range ids {
		c := newTestClient(hub, id)
		hub.handleRegister(c)
		clients = append(clients, c)
	}
	return clients
}

func join(hub *Hub, c *Client, roomID string) {
	hub.handleJoinRoom(&JoinRoomRequest{Client: c, RoomID: roomID})
}

func nextMessage(t *testing.T, c *Client) Message {
	t.Helper()
	select {
	case raw, ok := <-c.send:
		if !ok {
			t.Fatalf("client %s: send channel closed, wanted a message", c.ID)
		}
		var msg Message
		if err := json.Unmarshal(raw, &msg); err != nil {
			t.Fatalf("client %s: invalid message %s: %v", c.ID, raw, err)
		}
		return msg
	case <-time.After(time.Second):
		t.Fatalf("client %s: no message received", c.ID)
		return Message{}
	}
}

func expectNoMessage(t *testing.T, c *Client) {
	t.Helper()
	select {
	case raw := <-c.send:
		t.Fatalf("client %s: unexpected message %s", c.ID, raw)
	default:
	}
}

func parse[T any](t *testing.T, msg Message, want MessageType) T {
	t.Helper()
	if msg.Type != want {
		t.Fatalf("message type = %s, want %s", msg.Type, want)
	}
	var data T
	if err := msg.ParseData(&data); err != nil {
		t.Fatalf("parse %s data: %v", want, err)
	}
	return data
}

func TestJoinRoomSendsExistingPeersAndNotifiesThem(t *testing.T) {
	hub := NewHub()
	c := registered(hub, "a", "b")
	a, b := c[0], c[1]

	join(hub, a, "BBB:A1")
	first := parse[PeersData](t, nextMessage(t, a), MsgPeers)
	if len(first.Peers) != 0 {
		t.Errorf("first joiner got peers %v, want none", first.Peers)
	}

	join(hub, b, "BBB:A1")
	second := parse[PeersData](t, nextMessage(t, b), MsgPeers)
	if len(second.Peers) != 1 || second.Peers[0].ID != "a" {
		t.Errorf("second joiner got peers %v, want [a]", second.Peers)
	}

	joined := parse[PeerJoinedData](t, nextMessage(t, a), MsgPeerJoined)
	if joined.Peer.ID != "b" || joined.RoomID != "BBB:A1" {
		t.Errorf("existing peer notified of %+v, want b joining BBB:A1", joined)
	}
	expectNoMessage(t, b)
}

func TestSwitchingRoomsNotifiesOldRoomAndDropsEmptyRoom(t *testing.T) {
	hub := NewHub()
	c := registered(hub, "a", "b")
	a, b := c[0], c[1]
	join(hub, a, "BBB:A1")
	join(hub, b, "BBB:A1")
	nextMessage(t, a) // peers
	nextMessage(t, b) // peers
	nextMessage(t, a) // peer_joined b

	join(hub, a, "BBB:B1")

	left := parse[PeerLeftData](t, nextMessage(t, b), MsgPeerLeft)
	if left.PeerID != "a" || left.RoomID != "BBB:A1" {
		t.Errorf("old room notified %+v, want a left BBB:A1", left)
	}
	parse[PeersData](t, nextMessage(t, a), MsgPeers)

	if a.GetRoomID() != "BBB:B1" {
		t.Errorf("a room = %q, want BBB:B1", a.GetRoomID())
	}

	join(hub, b, "BBB:B1")
	if _, ok := hub.GetRoom("BBB:A1"); ok {
		t.Error("empty room BBB:A1 still exists")
	}
}

func TestLeaveRoomNotifiesPeersAndDeletesEmptyRoom(t *testing.T) {
	hub := NewHub()
	c := registered(hub, "a", "b")
	a, b := c[0], c[1]
	join(hub, a, "BBB:A1")
	join(hub, b, "BBB:A1")
	nextMessage(t, a)
	nextMessage(t, b)
	nextMessage(t, a)

	hub.handleLeaveRoom(&LeaveRoomRequest{Client: b, RoomID: "BBB:A1"})

	left := parse[PeerLeftData](t, nextMessage(t, a), MsgPeerLeft)
	if left.PeerID != "b" {
		t.Errorf("peer_left for %q, want b", left.PeerID)
	}
	if b.GetRoomID() != "" {
		t.Errorf("b room = %q after leaving, want empty", b.GetRoomID())
	}

	hub.handleLeaveRoom(&LeaveRoomRequest{Client: a, RoomID: "BBB:A1"})
	if _, rooms := hub.Stats(); rooms != 0 {
		t.Errorf("rooms = %d after everyone left, want 0", rooms)
	}
}

func TestLeaveUnknownRoomIsNoOp(t *testing.T) {
	hub := NewHub()
	a := registered(hub, "a")[0]

	hub.handleLeaveRoom(&LeaveRoomRequest{Client: a, RoomID: "nope"})

	expectNoMessage(t, a)
}

func TestUnregisterRemovesClientNotifiesRoomAndClosesSend(t *testing.T) {
	hub := NewHub()
	c := registered(hub, "a", "b")
	a, b := c[0], c[1]
	join(hub, a, "BBB:A1")
	join(hub, b, "BBB:A1")
	nextMessage(t, a)
	nextMessage(t, b)
	nextMessage(t, a)

	hub.handleUnregister(b)

	parse[PeerLeftData](t, nextMessage(t, a), MsgPeerLeft)
	if _, ok := hub.GetClient("b"); ok {
		t.Error("unregistered client still in hub")
	}
	if _, ok := <-b.send; ok {
		t.Error("unregistered client's send channel is still open")
	}

	// Unregistering twice must not panic on a double close.
	hub.handleUnregister(b)
}

func TestForwardDeliversOnlyToTargetInSameRoom(t *testing.T) {
	hub := NewHub()
	c := registered(hub, "a", "b", "outsider")
	a, b, outsider := c[0], c[1], c[2]
	join(hub, a, "BBB:A1")
	join(hub, b, "BBB:A1")
	join(hub, outsider, "BBB:B1")
	nextMessage(t, a)
	nextMessage(t, b)
	nextMessage(t, a)
	nextMessage(t, outsider)

	offer := OfferData{From: "a", To: "b", SessionID: "s1", Description: SDPDescription{Type: "offer", SDP: "v=0"}}
	hub.handleForwardToPeer(&ForwardRequest{From: a, TargetID: "b", MsgType: MsgOffer, Data: offer})

	got := parse[OfferData](t, nextMessage(t, b), MsgOffer)
	if got.SessionID != "s1" || got.Description.SDP != "v=0" {
		t.Errorf("forwarded offer = %+v, want session s1", got)
	}
	expectNoMessage(t, a)

	// Room isolation: a peer in another room is unreachable even by ID.
	hub.handleForwardToPeer(&ForwardRequest{From: a, TargetID: "outsider", MsgType: MsgOffer, Data: offer})
	expectNoMessage(t, outsider)
}

func TestForwardFromClientOutsideAnyRoomIsDropped(t *testing.T) {
	hub := NewHub()
	c := registered(hub, "loner", "b")
	loner, b := c[0], c[1]
	join(hub, b, "BBB:A1")
	nextMessage(t, b)

	hub.handleForwardToPeer(&ForwardRequest{From: loner, TargetID: "b", MsgType: MsgOffer, Data: OfferData{}})

	expectNoMessage(t, b)
}

func TestBroadcastSkipsExcludedClients(t *testing.T) {
	hub := NewHub()
	c := registered(hub, "a", "b", "c")
	for _, client := range c {
		join(hub, client, "BBB:A1")
	}
	for _, client := range c {
		for len(client.send) > 0 {
			<-client.send
		}
	}

	hub.handleBroadcastToRoom(&BroadcastRequest{
		RoomID:     "BBB:A1",
		ExcludeIDs: []string{"a"},
		MsgType:    MsgPeerTalking,
		Data:       PeerTalkingData{RoomID: "BBB:A1", PeerID: "a", IsTalking: true},
	})

	expectNoMessage(t, c[0])
	for _, listener := range c[1:] {
		talking := parse[PeerTalkingData](t, nextMessage(t, listener), MsgPeerTalking)
		if talking.PeerID != "a" || !talking.IsTalking {
			t.Errorf("%s got %+v, want a talking", listener.ID, talking)
		}
	}
}

func TestSendMessageDropsWhenBufferFull(t *testing.T) {
	hub := NewHub()
	a := registered(hub, "a")[0]
	msg, _ := NewMessage(MsgError, ErrorData{Code: "x"})

	for i := 0; i < cap(a.send)+10; i++ {
		a.SendMessage(msg) // must never block the hub
	}

	if len(a.send) != cap(a.send) {
		t.Errorf("buffered %d messages, want %d", len(a.send), cap(a.send))
	}
}
