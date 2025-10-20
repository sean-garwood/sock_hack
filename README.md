# Sock Hack

Reverse engineering the [Owlet DreamSock 3](http://localhost)

## Goals

* Learn about
  * reverse-engineering
  * IoT devices
  * embedded systems
* Evaluate the security of the web service(s) running on the device
* Modify the behavior of the device, if possible.

## Findings

The device comes with two components: a "sock", which consists of two devices--a
bluetooth module and some kind of (IR?) sensor that presumably can read
"pulseox"; and a "base station", which appears to act as an access point and
[requires setup via a third-party app on a
smartphone](./recon/docs/installation_manual.pdf)

### Web application

When powered, the base station appears to act as an access point. It does not
appear to allow outbound connections (see various [packet
captures](./recon/pcaps/)), except perhaps to call some API endpoint in the
[aylanetworks domain](./recon/docs/ayla_networks_api_docs.txt).

The [user interface](./app/index.html) can be accessed by connecting to the AP
and navigating to 192.168.0.1. It displays a list of all available wifi
networks, as well as connect buttons and stuff. It also loads [a pretty basic
script](./app/wifi.js) that serves as the controller.

#### Server-side functions

It seems that Window inherits from globalThis. the `window` object has a number
of methods for which the definitions are not visible.
