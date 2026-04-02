package main

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
)

// Temporal codec protocol types
type Payload struct {
	Metadata map[string]string `json:"metadata"`
	Data     string            `json:"data"` // base64-encoded
}

type PayloadList struct {
	Payloads []Payload `json:"payloads"`
}

const (
	metadataEncoding    = "encoding"
	encodingAESGCM      = "binary/encrypted"
	encodingOriginalKey = "encryption-original-encoding"
)

// b64 encodes a string to base64 for metadata values
func b64(s string) string {
	return base64.StdEncoding.EncodeToString([]byte(s))
}

// decodeMetadata decodes a base64-encoded metadata value, returning the raw string
func decodeMetadata(s string) string {
	b, err := base64.StdEncoding.DecodeString(s)
	if err != nil {
		return s
	}
	return string(b)
}

var encryptionKey []byte

func main() {
	keyB64 := os.Getenv("CODEC_ENCRYPTION_KEY")
	if keyB64 == "" {
		log.Fatal("CODEC_ENCRYPTION_KEY environment variable is required (base64-encoded 32-byte key)")
	}

	var err error
	encryptionKey, err = base64.StdEncoding.DecodeString(keyB64)
	if err != nil {
		log.Fatalf("Failed to decode CODEC_ENCRYPTION_KEY: %v", err)
	}
	if len(encryptionKey) != 32 {
		log.Fatalf("CODEC_ENCRYPTION_KEY must be exactly 32 bytes (got %d)", len(encryptionKey))
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/codec/encode", corsMiddleware(handleEncode))
	mux.HandleFunc("/codec/decode", corsMiddleware(handleDecode))
	mux.HandleFunc("/health", handleHealth)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8888"
	}

	log.Printf("Codec server listening on :%s", port)
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}

func corsMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if origin != "" {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type, X-Namespace")
			w.Header().Set("Access-Control-Allow-Credentials", "true")
		}
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next(w, r)
	}
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "ok")
}

func handleEncode(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	body, err := io.ReadAll(io.LimitReader(r.Body, 16<<20)) // 16MB limit
	if err != nil {
		http.Error(w, "failed to read body", http.StatusBadRequest)
		return
	}

	var input PayloadList
	if err := json.Unmarshal(body, &input); err != nil {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
		return
	}

	var output PayloadList
	for _, p := range input.Payloads {
		encrypted, err := encryptPayload(p)
		if err != nil {
			http.Error(w, fmt.Sprintf("encryption failed: %v", err), http.StatusInternalServerError)
			return
		}
		output.Payloads = append(output.Payloads, encrypted)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(output)
}

func handleDecode(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	body, err := io.ReadAll(io.LimitReader(r.Body, 16<<20))
	if err != nil {
		http.Error(w, "failed to read body", http.StatusBadRequest)
		return
	}

	var input PayloadList
	if err := json.Unmarshal(body, &input); err != nil {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
		return
	}

	var output PayloadList
	for _, p := range input.Payloads {
		// Only decrypt payloads that were encrypted by us
		if decodeMetadata(p.Metadata[metadataEncoding]) == encodingAESGCM {
			decrypted, err := decryptPayload(p)
			if err != nil {
				http.Error(w, fmt.Sprintf("decryption failed: %v", err), http.StatusInternalServerError)
				return
			}
			output.Payloads = append(output.Payloads, decrypted)
		} else {
			// Pass through unencrypted payloads
			output.Payloads = append(output.Payloads, p)
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(output)
}

func encryptPayload(p Payload) (Payload, error) {
	plaintext, err := base64.StdEncoding.DecodeString(p.Data)
	if err != nil {
		return Payload{}, fmt.Errorf("decode payload data: %w", err)
	}

	block, err := aes.NewCipher(encryptionKey)
	if err != nil {
		return Payload{}, fmt.Errorf("create cipher: %w", err)
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return Payload{}, fmt.Errorf("create GCM: %w", err)
	}

	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return Payload{}, fmt.Errorf("generate nonce: %w", err)
	}

	// Prepend nonce to ciphertext
	ciphertext := gcm.Seal(nonce, nonce, plaintext, nil)

	originalEncoding := p.Metadata[metadataEncoding]

	return Payload{
		Metadata: map[string]string{
			metadataEncoding:    b64(encodingAESGCM),
			encodingOriginalKey: originalEncoding,
		},
		Data: base64.StdEncoding.EncodeToString(ciphertext),
	}, nil
}

func decryptPayload(p Payload) (Payload, error) {
	ciphertext, err := base64.StdEncoding.DecodeString(p.Data)
	if err != nil {
		return Payload{}, fmt.Errorf("decode payload data: %w", err)
	}

	block, err := aes.NewCipher(encryptionKey)
	if err != nil {
		return Payload{}, fmt.Errorf("create cipher: %w", err)
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return Payload{}, fmt.Errorf("create GCM: %w", err)
	}

	nonceSize := gcm.NonceSize()
	if len(ciphertext) < nonceSize {
		return Payload{}, fmt.Errorf("ciphertext too short")
	}

	nonce, ciphertext := ciphertext[:nonceSize], ciphertext[nonceSize:]
	plaintext, err := gcm.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return Payload{}, fmt.Errorf("decrypt: %w", err)
	}

	originalEncoding := p.Metadata[encodingOriginalKey]
	if originalEncoding == "" {
		originalEncoding = b64("json/plain")
	}

	return Payload{
		Metadata: map[string]string{
			metadataEncoding: originalEncoding,
		},
		Data: base64.StdEncoding.EncodeToString(plaintext),
	}, nil
}

