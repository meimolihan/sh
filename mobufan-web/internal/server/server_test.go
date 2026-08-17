package server

import (
	"io/fs"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"testing/fstest"

	"mobufan/internal/docker"
)

func testServer() *Server {
	web := fstest.MapFS{
		"web/index.html": &fstest.MapFile{Data: []byte("<html>mobufan</html>")},
		"web/app.js":     &fstest.MapFile{Data: []byte("console.log('app')")},
		"web/style.css":  &fstest.MapFile{Data: []byte("body{}")},
	}
	return New("secret", docker.New(""), web)
}

func doRequest(t *testing.T, s *Server, method, path, token string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(method, path, nil)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	rr := httptest.NewRecorder()
	s.Handler().ServeHTTP(rr, req)
	return rr
}

func TestAuthRequired(t *testing.T) {
	s := testServer()
	rr := doRequest(t, s, "GET", "/api/system/info", "")
	if rr.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rr.Code)
	}
	if !strings.Contains(rr.Body.String(), "token") {
		t.Fatalf("unexpected body: %s", rr.Body.String())
	}
}

func TestAuthWrongToken(t *testing.T) {
	s := testServer()
	rr := doRequest(t, s, "GET", "/api/system/info", "wrong")
	if rr.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rr.Code)
	}
}

func TestAuthOKAndInfo(t *testing.T) {
	s := testServer()
	rr := doRequest(t, s, "GET", "/api/system/info", "secret")
	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d body=%s", rr.Code, rr.Body.String())
	}
	if !strings.Contains(rr.Body.String(), "hostname") {
		t.Fatalf("unexpected body: %s", rr.Body.String())
	}
}

func TestRootServesIndex(t *testing.T) {
	s := testServer()
	rr := doRequest(t, s, "GET", "/", "")
	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rr.Code)
	}
	if !strings.Contains(rr.Body.String(), "mobufan") {
		t.Fatalf("unexpected body: %s", rr.Body.String())
	}
}

func TestHealthPublic(t *testing.T) {
	s := testServer()
	rr := doRequest(t, s, "GET", "/api/health", "")
	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rr.Code)
	}
	if !strings.Contains(rr.Body.String(), `"docker":false`) {
		t.Fatalf("unexpected body: %s", rr.Body.String())
	}
}

func TestDockerDisabled503(t *testing.T) {
	s := testServer()
	rr := doRequest(t, s, "GET", "/api/docker/info", "secret")
	if rr.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503, got %d body=%s", rr.Code, rr.Body.String())
	}
}

var _ fs.FS = fstest.MapFS{}
