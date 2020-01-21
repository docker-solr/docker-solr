#!/usr/bin/env python3

#
# Script which serves local solr tgz files simulating an Apache mirror server
#

from http.server import BaseHTTPRequestHandler, HTTPServer
import os
import sys

PORT_NUMBER = 8083

#This class will handle any incoming request
class myHandler(BaseHTTPRequestHandler):

    def do_GET(self):
        if self.path.endswith("quit"):
            print("Exiting")
            server.socket.close()
            sys.exit()
        file = "./downloads/%s" % self.path.split("/")[-1]
        if not os.path.exists(file):
            self.send_response(404)
            self.end_headers()
            self.wfile.write(("File %s not found" % file).encode())
            return
        try:
            with open(file, 'rb') as f:
                size = os.path.getsize(file)
                self.send_response(200)
                self.send_header('Content-type', 'application/gzip')
                self.send_header('Content-length', size)
                self.end_headers()
                self.wfile.write(f.read())
                return
        except Exception as e:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(("Error: %s" % e).encode())
            return


try:
    server = HTTPServer(('', PORT_NUMBER), myHandler)
    print("Started local web server serving Solr artifacts on port %s" % PORT_NUMBER)
    server.serve_forever()

except KeyboardInterrupt:
    print("^C received, shutting down the web server")
    server.socket.close()