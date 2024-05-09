(
//MUSICAL SKETCH PAD
s.waitForBoot({
var point, red, green, blue, win, view, colorTask, redChange, greenChange, blueChange;

//simple synthdef - short enveloped variable duty saw wave
SynthDef(\note, {
	arg freq=440, width=0.5, pan=0, amp=1, length=1;
	var sig, env;
	env = EnvGen.kr(Env([0,1,0],[0.012,0.012]*length,\linear),doneAction:2);
	sig = VarSaw.ar(freq, 0, width);
	sig = Pan2.ar(sig, pan, amp);
	sig = sig * env;
	Out.ar(0, sig);
}).add;


//default starting RGB values
//these values can be changed as well
//maintain range of 0â‰¤xâ‰¤1
red=0; green=0.33; blue=0.67;

//rate of change of each color component
//mess around with these values for fun
//zero results in no color change
redChange = 0.01;
greenChange = 0.015;
blueChange = 0.02;

//RGB values wrap through range 0â‰¤x<2
//and are folded into 0â‰¤xâ‰¤1 via mouseMove function
//thus RGB values oscillate linearly, out of phase with
//one another, back and forth from 0 to 1
colorTask = Task({
	{
		red = (red + redChange)%2;
		green = (green + greenChange)%2;
		blue = (blue + blueChange)%2;
		0.05.wait; //arbitrary wait time
	}.loop;
});


//window creation
win = Window("FANCY ARTWORK", resizable:true, border:true);
	// win.fullScreen;
win.onClose = {
	if(
		colorTask.isPlaying,
		{colorTask.stop}
	);
};

//userview creation
view = UserView(win, Window.screenBounds);
view.clearOnRefresh = false;
view.background = Color.white;

//any click sets point as current mouse location
//left-click does nothing special
//right-click clears palette
view.mouseDownAction = {
	|v, x, y, mod, butNum, clkCnt|
	point = [x,y];
	if(butNum == 1,
		{
			v.drawFunc_({nil});
			v.clearDrawing;
			v.refresh},{}
	);
};

//mouse drag redefines userview drawFunc
//Pen draws line from old point to current point
//then sets old point equal to current point
view.mouseMoveAction = {
	|v, x, y|
	var penWidth=3;
	v.drawFunc = {
		Pen.strokeColor = Color.new(
			red.fold(0,1),
			green.fold(0,1),
			blue.fold(0,1)
		);
		Pen.width = penWidth;
		Pen.line(point.asPoint,x@y);
		point = [x,y];
		Pen.stroke;
		};
	win.refresh;
	Synth(\note, [
		\freq, ((x/(Window.screenBounds.width)).linlin(0,1,32,100)).midicps,
//		\freq, exprand(40.0,2000,0),
//		\freq, ((x/(Window.screenBounds.width)).linlin(0,1,32,90).round(5) + [0,3,7].choose).midicps,
		\width, (y/(Window.screenBounds.height)).linlin(0,1,0.001,0.5),
		\pan, x.linlin(0,Window.screenBounds.width,-1,1),
//		\pan, rrand(-0.8,0.8),
		\amp, 0.1,
		\length, penWidth
	]);
};

//comment out for no color change
colorTask.start;

win.front;
});
)