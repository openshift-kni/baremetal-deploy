package main

import (
	"flag"
	"log"
	"net"

	"github.com/ishidawataru/sctp"
)

func main() {
	var server = flag.Bool("server", false, "")
	var ip = flag.String("ip", "0.0.0.0", "")
	var port = flag.Int("port", 0, "")
	var lport = flag.Int("lport", 0, "")

	flag.Parse()

	if *server {
		doServer(*ip, *port)
	} else {
		doClient(*ip, *port, *lport)
	}

}

func doClient(serverAddr string, port int, localport int) {
	address, err := net.ResolveIPAddr("ip", serverAddr)

	server := &sctp.SCTPAddr{
		IPAddrs: []net.IPAddr{*address},
		Port:    port,
	}

	var laddr *sctp.SCTPAddr
	if localport != 0 {
		laddr = &sctp.SCTPAddr{
			Port: localport,
		}
	}
	conn, err := sctp.DialSCTP("sctp", laddr, server)
	if err != nil {
		log.Fatalf("failed to dial: %v", err)
	}

	log.Printf("Dail LocalAddr: %s; RemoteAddr: %s", conn.LocalAddr(), conn.RemoteAddr())
	info := sctp.SndRcvInfo{
		Stream: uint16(0),
		PPID:   uint32(0),
	}

	n, err := conn.SCTPWrite([]byte("hello"), &info)
	if err != nil {
		log.Fatalf("failed to write: %v", err)
	}
	log.Printf("write: len %d", n)

}

func doServer(serverAddr string, port int) {
	address, err := net.ResolveIPAddr("ip", serverAddr)

	listenAddr := &sctp.SCTPAddr{
		IPAddrs: []net.IPAddr{*address},
		Port:    port,
	}
	ln, err := sctp.ListenSCTP("sctp", listenAddr)
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}
	log.Printf("Listen on %s", ln.Addr())

	conn, err := ln.Accept()
	if err != nil {
		log.Fatalf("failed to accept: %v", err)
	}
	log.Printf("Accepted Connection from RemoteAddr: %s", conn.RemoteAddr())
	buf := make([]byte, 512)
	n, err := conn.Read(buf)
	if err != nil {
		log.Fatalf("read failed: %v", err)
	}
	log.Printf("Received: %s", string(buf[:n]))
}
