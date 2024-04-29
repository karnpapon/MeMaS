#include <Bela.h>
#include <libraries/OscSender/OscSender.h>

OscSender oscSender;
int remotePort = 57120;
const char* remoteIp = "127.0.0.1";

// parse messages received by the OSC receiver
// msg is Message class of oscpkt: http://gruntthepeon.free.fr/oscpkt/
bool handshakeReceived;

bool setup(BelaContext *context, void *userData) {
	oscSender.setup(remotePort, remoteIp);

	// the following code sends an OSC message to address /osc-setup
	// then waits 1 second for a reply on /osc-setup-reply
	oscSender.newMessage("/osc-setup").send();
	int count = 0;
	int timeoutCount = 10;
	printf("Waiting for handshake ....\n");
	while(!handshakeReceived && ++count != timeoutCount) {
		usleep(100000);
	}
	if (handshakeReceived) {
		printf("handshake received!\n");
	} else {
		printf("timeout! : did you start the node server? `node /root/Bela/resources/osc/osc.js\n");
		return false;
	}
	return true;
}

void render(BelaContext *context, void *userData) {

}

void cleanup(BelaContext *context, void *userData) {

}