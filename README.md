# Project 16: Enable HTTPS using ACM

## Overview
This repository provisions an AWS Application Load Balancer configured with an HTTPS listener using a self-signed ACM certificate.

## Features
* **ACM Integration:** Dynamic self-signed certificate generation and ACM import.
* **HTTPS Listener:** Secure traffic routing on port 443.
* **HTTP Blocking:** Explicit port 80 listener returning a `403 Forbidden` response to block unencrypted traffic.
