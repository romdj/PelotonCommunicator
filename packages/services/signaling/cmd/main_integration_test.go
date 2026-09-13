//go:build integration

package main

import (
	"encoding/json"
	"errors"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"

	ws "github.com/peloton-communicator/signaling/internal/websocket"
)

// Integration tests run the real HTTP handlers and hub over real WebSocket connections,
// exercising the same signaling path two phones use during a ride.
//
// Run with: go test -tags=integration ./...

func startServer(t *testing.T) *httptest.Server {
	t.Helper()
	hub := ws.NewHub()
	go hub.Run()

	mux := http.NewServeMux()
	mux.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) { handleWebSocket(hub, w, r) })
	mux.HandleFunc("/health", handleHealth)
	mux.HandleFunc("/stats", func(w http.ResponseWriter, r *http.Request) { handleStats(hub, w, r) })

	server := httptest.NewServer(mux)
	t.Cleanup(server.Close)
	return server
}

type rider struct {
	t    *testing.T
	name string
	conn *websocket.Conn
}

func connect(t *testing.T, server *httptest.Server, name string) *rider {
	t.Helper()
	url := "ws" + strings.TrimPrefix(server.URL, "http") + "/ws?userId=" + name
	conn, _, err := websocket.DefaultDialer.Dial(url, nil)
	if err != nil {
		t.Fatalf("%s: dial: %v", name, err)
	}
	t.Cleanup(func() { conn.Close() })
	return &rider{t: t, name: name, conn: conn}
}

func (r *rider) send(msgType ws.MessageType, data any) {
	r.t.Helper()
	msg, err := ws.NewMessage(msgType, data)
	if err != nil {
		r.t.Fatalf("%s: build %s: %v", r.name, msgType, err)
	}
	if err := r.conn.WriteJSON(msg); err != nil {
		r.t.Fatalf("%s: send %s: %v", r.name, msgType, err)
	}
}

func (r *rider) expect(msgType ws.MessageType, into any) {
	r.t.Helper()
	r.conn.SetReadDeadline(time.Now().Add(2 * time.Second))
	var msg ws.Message
	if err := r.conn.ReadJSON(&msg); err != nil {
		r.t.Fatalf("%s: waiting for %s: %v", r.name, msgType, err)
	}
	if msg.Type != msgType {
		r.t.Fatalf("%s: got %s (%s), want %s", r.name, msg.Type, msg.Data, msgType)
	}
	if into != nil {
		if err := json.Unmarshal(msg.Data, into); err != nil {
			r.t.Fatalf("%s: parse %s: %v", r.name, msgType, err)
		}
	}
}

func (r *rider) expectSilence() {
	r.t.Helper()
	r.conn.SetReadDeadline(time.Now().Add(300 * time.Millisecond))
	var msg ws.Message
	err := r.conn.ReadJSON(&msg)
	var netErr net.Error
	if err == nil {
		r.t.Fatalf("%s: unexpected %s (%s)", r.name, msg.Type, msg.Data)
	}
	if !errors.As(err, &netErr) || !netErr.Timeout() {
		r.t.Fatalf("%s: expected read timeout, got %v", r.name, err)
	}
}

func TestHealthEndpoint(t *testing.T) {
	server := startServer(t)

	resp, err := http.Get(server.URL + "/health")
	if err != nil {
		t.Fatalf("GET /health: %v", err)
	}
	defer resp.Body.Close()

	var body map[string]string
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if resp.StatusCode != http.StatusOK || body["status"] != "healthy" {
		t.Errorf("GET /health = %d %v, want 200 healthy", resp.StatusCode, body)
	}
}

// Two riders in the same group negotiate a WebRTC session and signal push-to-talk, while
// a rider in a different group hears none of it.
func TestTwoRidersSignalAWalkieTalkieSession(t *testing.T) {
	server := startServer(t)
	alice := connect(t, server, "alice")
	bob := connect(t, server, "bob")
	carol := connect(t, server, "carol")

	alice.send(ws.MsgJoinRoom, ws.JoinRoomData{RoomID: "BBB:A1"})
	var alicePeers ws.PeersData
	alice.expect(ws.MsgPeers, &alicePeers)
	if len(alicePeers.Peers) != 0 {
		t.Fatalf("alice joined an empty room but saw peers %v", alicePeers.Peers)
	}

	carol.send(ws.MsgJoinRoom, ws.JoinRoomData{RoomID: "BBB:B1"})
	carol.expect(ws.MsgPeers, nil)

	bob.send(ws.MsgJoinRoom, ws.JoinRoomData{RoomID: "BBB:A1"})
	var bobPeers ws.PeersData
	bob.expect(ws.MsgPeers, &bobPeers)
	if len(bobPeers.Peers) != 1 || bobPeers.Peers[0].UserID != "alice" {
		t.Fatalf("bob saw peers %v, want [alice]", bobPeers.Peers)
	}
	aliceID := bobPeers.Peers[0].ID

	var joined ws.PeerJoinedData
	alice.expect(ws.MsgPeerJoined, &joined)
	if joined.Peer.UserID != "bob" {
		t.Fatalf("alice notified of %+v, want bob", joined.Peer)
	}
	bobID := joined.Peer.ID

	// Offer / answer / ICE are relayed peer-to-peer, with the server stamping the sender.
	alice.send(ws.MsgOffer, ws.OfferData{To: bobID, From: "spoofed", SessionID: "s1",
		Description: ws.SDPDescription{Type: "offer", SDP: "v=0 offer"}})
	var offer ws.OfferData
	bob.expect(ws.MsgOffer, &offer)
	if offer.From != aliceID || offer.Description.SDP != "v=0 offer" {
		t.Fatalf("bob got offer %+v, want from %s with alice's SDP", offer, aliceID)
	}

	bob.send(ws.MsgAnswer, ws.AnswerData{To: aliceID, SessionID: "s1",
		Description: ws.SDPDescription{Type: "answer", SDP: "v=0 answer"}})
	var answer ws.AnswerData
	alice.expect(ws.MsgAnswer, &answer)
	if answer.From != bobID {
		t.Fatalf("alice got answer from %q, want %q", answer.From, bobID)
	}

	alice.send(ws.MsgCandidate, ws.CandidateData{To: bobID, Candidate: ws.ICECandidate{Candidate: "candidate:1"}})
	var candidate ws.CandidateData
	bob.expect(ws.MsgCandidate, &candidate)
	if candidate.Candidate.Candidate != "candidate:1" {
		t.Fatalf("bob got candidate %+v", candidate)
	}

	// Push-to-talk start/end reaches the group, not the talker, and not other groups.
	alice.send(ws.MsgPTTStart, ws.PTTStartData{RoomID: "BBB:A1"})
	var talking ws.PeerTalkingData
	bob.expect(ws.MsgPeerTalking, &talking)
	if talking.PeerID != aliceID || !talking.IsTalking {
		t.Fatalf("bob got %+v, want alice talking", talking)
	}

	alice.send(ws.MsgPTTEnd, ws.PTTEndData{RoomID: "BBB:A1"})
	bob.expect(ws.MsgPeerTalking, &talking)
	if talking.IsTalking {
		t.Fatalf("bob got %+v, want alice stopped talking", talking)
	}

	// Dropping a connection tells the rest of the group.
	bob.conn.Close()
	var left ws.PeerLeftData
	alice.expect(ws.MsgPeerLeft, &left)
	if left.PeerID != bobID {
		t.Fatalf("alice notified %q left, want %q", left.PeerID, bobID)
	}

	// Silence checks go last: gorilla/websocket treats a read timeout as permanent, so a
	// connection can't be read again after expectSilence.
	alice.expectSilence()
	carol.expectSilence()
}

func TestPTTBeforeJoiningARoomIsRejected(t *testing.T) {
	server := startServer(t)
	rider := connect(t, server, "early")

	rider.send(ws.MsgPTTStart, ws.PTTStartData{})

	var errData ws.ErrorData
	rider.expect(ws.MsgError, &errData)
	if errData.Code != "not_in_room" {
		t.Errorf("error code = %q, want not_in_room", errData.Code)
	}
}

func TestUnknownMessageTypeIsRejected(t *testing.T) {
	server := startServer(t)
	rider := connect(t, server, "confused")

	if err := rider.conn.WriteMessage(websocket.TextMessage, []byte(`{"type":"teleport","data":{}}`)); err != nil {
		t.Fatalf("write: %v", err)
	}

	var errData ws.ErrorData
	rider.expect(ws.MsgError, &errData)
	if errData.Code != "unknown_type" {
		t.Errorf("error code = %q, want unknown_type", errData.Code)
	}
}
