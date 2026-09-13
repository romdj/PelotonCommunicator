package websocket

import (
	"encoding/json"
	"testing"
	"time"
)

func TestNewMessageRoundTripsData(t *testing.T) {
	msg, err := NewMessage(MsgJoinRoom, JoinRoomData{RoomID: "BBB:A1", UserID: "rider-1"})
	if err != nil {
		t.Fatalf("NewMessage: %v", err)
	}

	var got JoinRoomData
	if err := msg.ParseData(&got); err != nil {
		t.Fatalf("ParseData: %v", err)
	}

	if msg.Type != MsgJoinRoom || got.RoomID != "BBB:A1" || got.UserID != "rider-1" {
		t.Errorf("round trip = %s %+v, want join_room BBB:A1 rider-1", msg.Type, got)
	}
}

// The Flutter client depends on these exact JSON field names; renaming a Go struct tag
// silently breaks signaling on the phones.
func TestWireFormatMatchesFlutterClient(t *testing.T) {
	msg, err := NewMessage(MsgPeerTalking, PeerTalkingData{RoomID: "r", PeerID: "p", IsTalking: true})
	if err != nil {
		t.Fatalf("NewMessage: %v", err)
	}
	raw, err := json.Marshal(msg)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	want := `{"type":"peer_talking","data":{"roomId":"r","peerId":"p","isTalking":true}}`
	if string(raw) != want {
		t.Errorf("wire format = %s, want %s", raw, want)
	}
}

func TestNewMessageRejectsUnmarshalableData(t *testing.T) {
	if _, err := NewMessage(MsgError, make(chan int)); err == nil {
		t.Error("NewMessage with a channel payload returned nil error")
	}
}

func TestNewPeerStampsJoinTime(t *testing.T) {
	before := time.Now().Unix()
	peer := NewPeer("client_1", "rider-1", "Pixel")

	if peer.ID != "client_1" || peer.UserID != "rider-1" || peer.DeviceInfo != "Pixel" {
		t.Errorf("NewPeer = %+v, want fields copied", peer)
	}
	if peer.JoinedAt < before {
		t.Errorf("JoinedAt = %d, want >= %d", peer.JoinedAt, before)
	}
}
