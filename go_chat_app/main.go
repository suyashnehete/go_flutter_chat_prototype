// main.go

package main

import (
	"fmt"
	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
	"net/http"
	"sync"
	"time"
)

var (
	// for web scoket
	users    = make(map[string]*websocket.Conn)
	usersMux sync.Mutex

	// if web socket fails
	messageQueue   = make(chan string, 100)
	subscribers    = make(map[string]chan string)
	subscribersMux sync.Mutex
)

func main() {
	r := gin.Default()

	// Serve frontend
	r.Static("/static", "./static")

	// WebSocket endpoint
	r.GET("/ws", func(c *gin.Context) {
		handleWebSocketConnection(c.Writer, c.Request)
	})

	///  if websocket fails
	// Long polling endpoint
	r.GET("/poll/:username", func(c *gin.Context) {
		handleLongPolling(c)
	})

	// Message sending endpoint
	r.POST("/send/:username", func(c *gin.Context) {
		handleSendMessage(c)
	})

	// Start the server
	r.Run(":8080")
}

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

func handleWebSocketConnection(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		fmt.Println(err)
		return
	}

	// Assume the user is identified by a unique username (in a real app, use proper authentication)
	username := r.URL.Query().Get("username")

	// Register the user's WebSocket connection
	usersMux.Lock()
	users[username] = conn
	usersMux.Unlock()

	// Handle incoming messages
	for {
		var message map[string]string
		err := conn.ReadJSON(&message)
		fmt.Print(message)
		if err != nil {
			fmt.Println(err)
			break
		}

		// Assume the message includes a "to" field indicating the recipient
		from := message["from"]
		to := message["to"]
		fmt.Print(from)
		if sender, ok := users[from]; ok {
			err := sender.WriteJSON(message)
			if err != nil {
				fmt.Println(err)
				break
			}
		}

		if recipient, ok := users[to]; ok {
			err := recipient.WriteJSON(message)
			if err != nil {
				fmt.Println(err)
				break
			}
		}
	}

	// Handle WebSocket closure
	usersMux.Lock()
	delete(users, username)
	usersMux.Unlock()
	// Close the WebSocket connection
	err = conn.Close()
	if err != nil {
		fmt.Println(err)
	}
}

func handleLongPolling(c *gin.Context) {
	username := c.Param("username")

	subscribersMux.Lock()
	ch := subscribers[username]
	if ch == nil {
		ch = make(chan string, 1)
		subscribers[username] = ch
	}
	subscribersMux.Unlock()

	select {
	case msg := <-ch:
		c.JSON(http.StatusOK, gin.H{"message": msg})
	case <-time.After(30 * time.Second): // Timeout after 30 seconds
		c.JSON(http.StatusOK, gin.H{"message": ""})
	}
}

func handleSendMessage(c *gin.Context) {
	username := c.Param("username")

	var message struct {
		Message string `json:"message"`
	}

	if err := c.BindJSON(&message); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
		return
	}

	// Broadcast the message to subscribers
	subscribersMux.Lock()
	ch := subscribers[username]
	subscribersMux.Unlock()

	if ch != nil {
		select {
		case ch <- message.Message:
		default:
			// If the channel is full, drop the message (consider handling this differently in a production scenario)
		}
	}

	c.JSON(http.StatusOK, gin.H{"status": "Message sent"})
}
