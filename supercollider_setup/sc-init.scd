// [1]
(
MIDIClient.init;
// s.options.outDevice = "Scarlett 2i4 USB";
// s.options.outDevice ="MacBook Pro Speakers";
// s.options.outDevice ="BlackHole 16ch";
s.options.numInputBusChannels = 0;
s.options.numOutputBusChannels = 16;
s.boot;

s.waitForBoot{
	// n = NanoKontrol();  // https://github.com/karnpapon/NanoKontrol
	s.plotTree;
	// ~sampler_engine = MeMaSEngine("/Users/karnpaponboonput/Desktop/codes/opencv-pingpong-tracking/mapping_sounds/");

	~sampler_engine = MeMaSEngine("/Users/karnpaponboonput/Desktop/samples/soundpharm/FoleyPerc - Loops/");

}
)

~sampler_engine.analyze;
~sampler_engine.map_dataset;

(
~sampler_engine.normalize;
~sampler_engine.map_kd_tree(0.01);
)

~sampler_engine.exportProcessedData("/Users/karnpaponboonput/Desktop/codes/opencv-pingpong-tracking/mapping_sounds_data/", "my-live-perf-data");

~sampler_engine.exportProcessedData("/Users/karnpaponboonput/Desktop/test-pref-data/", "my-live-perf-data");

// [2]: for using in \demo_corpus
(
~sampler_engine.loadPreProcessedData("/Users/karnpaponboonput/Desktop/codes/opencv-pingpong-tracking/mapping_sounds_data");
)

// test data
~sampler_engine.loadPreProcessedData("/Users/karnpaponboonput/Desktop/test-pref-data");


// [3]: setup faders/sliders
// should add it to ServerTree ?
// so it can survive after `Cmd+Period`
/*(
if(c.notNil){
(c.faders.size).do{|fader,i| c.faders[i].free};
(c.knobs.size).do{|knob,i| c.knobs[i].free};
};

n.faders.do{|fader, i |
fader.onChange = {|fadervalue|
fadervalue.postln;
c.faders.at(i).set(fadervalue/127);
}
};

n.knobs.do{|knob, i |
knob.onChange = {|knobvalue|
knobvalue.postln;
c.knobs.at(i).set(knobvalue/127);
}
};

c = ();  // controlBusses
c.faders = Array.fill(9,{Bus.control(s,1).set(0.0)});
c.knobs = Array.fill(9, {Bus.control(s,1).set(0.25)});
)*/


// [4]: setup SynthDef
(
SynthDef(\drm, {|out, pew=1, sustain=1, pan, fed=0, tun|
	var env, sound, freq;
	tun = ((tun>0)*tun) + ((tun<1)*3);
	freq = (tun*10).midicps;
	env = EnvGen.ar(Env.linen(0.01, 0, 1, 1, -3), timeScale:sustain, doneAction:2);
	sound = LPF.ar(SinOscFB.ar(XLine.ar(freq.expexp(10, 2000, 1000, 8000), freq, 0.025/pew), fed), 9000);
	OffsetOut.ar(out, CleanPan.ar(sound, 2, pan, env))
}).add;

// testing sound
SynthDef(\metro, {
	var sig = SinOsc.ar(330,0);
	var env = EnvGen.kr(Env.perc(0.01, 0.125, 1, -4), doneAction: 2);
	sig = sig * env;
	Out.ar(0, sig!2);
}).add
)

// [5]: setup mixer (ddwMixerChannel: https://github.com/supercollider-quarks/ddwMixerChannel)
(
~srcMixerChannel = MixerChannel(\channel_1, s, 2, 2, 1);
~src2MixerChannel = MixerChannel(\channel_2, s, 2, 2, 1);
~src3MixerChannel = MixerChannel(\channel_3, s, 2, 2, 1);
~reverbMixerChannel = MixerChannel(\channel_fx_rvb, s, 2, 2, level: 1,
	completionFunc: { |chan|
		~rvb = chan.playfx { |outbus|
			var sig = In.ar(outbus, 2);
			FreeVerb2.ar(sig[0], sig[1], mix: 1, room: 0.8, damp: 0.2);
		}
	}
); // reverb is being add here

~delayMixerChannel = MixerChannel(\channel_fx_delay, s, 2, 2, level: 1,
	completionFunc: { |chan|
		~del = chan.playfx {|outbus,maxdelaytime=0.25,decaytime=4|
			Mix.arFill(4, { CombL.ar(In.ar(outbus, 1), maxdelaytime, LFNoise1.kr(Rand(0, 0.1), 0.1, 0.2), decaytime) })
		};
	}
); // delay is being add here
)

// [5.5]: correct group order after `Cmd+Period`
(
~reverbMixerChannel.fadergroup.moveToTail(s.defaultGroup);
~delayMixerChannel.fadergroup.moveToTail(s.defaultGroup);
)

/*(
~srcMixerChannel.free;
~src2MixerChannel.free;
~reverbMixerChannel.free;
~delayMixerChannel.free;
)*/

// [6]: setup fx chains;
(
~shaper = ~srcMixerChannel.playfx({ |outbus,in, shape = 0, amp = 1.0,  amp_compensation_amount = 0.99, lo = 0, hi = 0.5, offset = 0, lo_thresh = 0, hi_thresh = 0|
	var abs, diff, numChannels = 2;
	var sig = In.ar(outbus, numChannels);
	shape = min(shape, 1.0 - 4e-10).explin(0.001, 1, 0.0, 0.999999);
	amp_compensation_amount = amp_compensation_amount.linlin(0.0,1.0,0.0001,1.0);
	amp = 1.0 - (amp_compensation_amount * shape / (shape +amp_compensation_amount )) * amp;
	shape = (1.0 * shape) / (1.0 - shape);
	sig = (1 + shape) * sig / (1 + (shape * abs(sig)));
	offset = offset.linlin(0.0,1.0,1.0,5.0);
	hi = hi * offset; lo = lo * offset;
	abs = hi - lo;
	lo_thresh = lo_thresh.linlin(0.0,1.0,-1.0,1.0);
	lo = lo + (abs * lo_thresh);
	hi_thresh = hi_thresh.linlin(0.0,1.0,-1.0,1.0);
	hi = hi - (abs * hi_thresh);
	sig = Fold.ar(sig, lo, hi);
	diff = 1 - (lo - hi + (hi * lo));
	Limiter.ar(LeakDC.ar(sig * (amp+diff)));
});

~dist = ~srcMixerChannel.playfx({ |outbus, dst = 0|
	var sig, mod;
	sig = In.ar(outbus, 2);
	mod = CrossoverDistortion.ar(sig, amp: 0.2, smooth: 0.01);
	mod = mod + (0.1 * dst * DynKlank.ar(`[[60,61,240,3000 + SinOsc.ar(62,mul: 100)],nil,[0.1, 0.1, 0.05, 0.01]], sig));
	mod = (mod.cubed * 8).softclip * 0.5;
	mod = SelectX.ar(dst, [sig, mod]);
});

~triode = ~srcMixerChannel.playfx({
	|outbus,in, tri=0|
	var sig, sc;
	sig = In.ar(outbus,2);
	sc = tri * 10 + 0.001;
	sig = (sig * (sig > 0)) + (tanh(sig * sc) / sc * (sig < 0));
	LeakDC.ar(sig);
});

~lpf = ~srcMixerChannel.playfx({
	|outbus,in, cutoff = 1, resonance = 0|
	var numChannels = 2;
	var sig = In.ar(outbus, numChannels);
	var cutoffClipped = cutoff.linexp(0.0, 1.0, 40, 20000);
	sig = RLPF.ar(sig, cutoffClipped, resonance.linexp(0, 1, 1, 0.001));
});
)


// [8]: map Korg NanoKontrol (faders/slides)
/*(
~srcMixerChannel.synth.set(\level, c.faders.at(0).asMap); // fader[0] -> src level [\demo_kick]
~src2MixerChannel.synth.set(\level, c.faders.at(1).asMap); // fader[1] -> src2 level [\demo_corpus]
~lpf.set(\cutoff, c.knobs.at(8).asMap); // knob[8] -> cutoff level
~postsend.sendSynth.set(\level, c.knobs.at(0).asMap); // knob[1] -> sendLevel
~postsend2.sendSynth.set(\level, c.knobs.at(1).asMap); // knob[1] -> sendLevel
~postsend2.sendSynth.set(\level, c.faders.at(2).asMap); // fader[2] -> sendLevel
~dist.set(\dst, c.knobs.at(2).asMap); // knob[2] -> distortion level
~triode.set(\tri, c.knobs.at(3).asMap); // knob[3] -> triode level
~shaper.set(\offset, c.knobs.at(4).asMap); // knob[4] -> shaper::shape level
~shaper.set(\lo, c.knobs.at(5).asMap); // knob[5] -> shaper::lo level
~shaper.set(\hi, c.knobs.at(6).asMap); // knob[6] -> shaper::hi level
~shaper.set(\lo_thresh, c.knobs.at(7).asMap); // knob[7] -> shaper::lo_thresh level
// ~shaper.set(\hi_thresh, c.knobs.at(8).asMap); // knob[8] -> shaper::hi_thresh level
)*/

// ----------------Mixer----------------
~board = MixingBoard("mixer", nil,~srcMixerChannel, ~src2MixerChannel, ~src3MixerChannel, ~reverbMixerChannel, ~delayMixerChannel );


// ---------------MeMasEngine-----------
// inject GUI and then start engine.
(
var kNearest, kNearestDist;
var buttonValue="OSC";

w = Window("test",Rect(0,0,600,480+(20*2) ), resizable: false, border: false).front;
w.view.decorator = FlowLayout(w.view.bounds);
~sampler_engine.controller(parent: w);

// inject out_target to MyLivePerformance lib.
~sampler_engine.external_mixer_(~src2MixerChannel);

t = ToggleButton(w,buttonValue,{
	arg button,bool;
	~sampler_engine.toggleOSC(true);
},{
	arg button,bool;
	~sampler_engine.toggleOSC(false);
},false,100,20, Color.green, Color.white);

StaticText(w,Rect(0,0,40,20)).string_("neighbours:");
kNearest = TextView(w, Rect(0,0,40,20)).string_("").editable_(false);
StaticText(w,Rect(0,0,70,20)).string_("distances:");
kNearestDist = TextView(w, w.view.decorator.indentedRemaining.width@20).string_("").editable_(false);
~sampler_engine.listen(parent: w, kNearest: kNearest, kNearestDist: kNearestDist);
)


// ----------------MPU6050---------------
(
var knobX, knobY, knobZ, knobLpf, knobReso;
w=Window("MPU6050", Rect(0, 600, 400, 120), border: true).front;
w.view.decorator = FlowLayout( w.view.bounds, 10@10, 20@5 );

knobX=EZKnob(w,60@90," GYRO_X ",ControlSpec(0, 127, \lin, 1, 0), {|ez|
	// var knobVal = (ez.value).linlin(0,127,0,1);
	// ~dist.set(\dst, knobVal);
	// var knobVal = (ez.value).linlin(0,127,3,200)*0.8;
	// Ndef(\nanite).set(\nf, knobVal)
});
knobY=EZKnob(w,60@90," GYRO_Y ",ControlSpec(0, 127, \lin, 1, 0), {|ez|
	// var knobVal = (ez.value).linlin(0,127,0,1);
	// ~triode.set(\tri, knobVal);
});
knobZ=EZKnob(w,60@90," GYRO_Z ",ControlSpec(0, 127, \lin, 1, 0), {|ez|
	// var knobVal = (ez.value).linlin(0,127,0,1);
	// ~shaper.set(\lo, knobVal);
});

knobLpf=EZKnob(w,60@90," CUTOFF ",ControlSpec(0, 1, \lin, 0.01, 1), {|ez|
	~lpf.set(\cutoff, ez.value);
});

knobReso=EZKnob(w,60@90," RESON ",ControlSpec(0, 1, \lin, 0.01, 0), {|ez|
	~lpf.set(\resonance, ez.value);
});

OSCdef(\coordChanged, {
	arg msg;
	// msg[1].postln;
	defer {
		knobX.value_(if(msg[1] == 0, 0, (msg[1])*2)).doAction;
		knobY.value_(if(msg[2].neg == 0, 0, (127-(msg[2].neg))*2.5)).doAction;
		knobZ.value_(if(msg[3].neg == 0, 0, (127-(msg[3].neg))*2.5)).doAction;
	};

	// kick with pre-defined Pattern!
	if(msg[1] != 0 && ((msg[1] % 40)==0), {
		Synth(\drm, [
			\dur, 1 / Pwrand([5, 10], [3, 8].normalizeSum, 1).asStream.value * 2,
			\tun, Pdup(Pexprand(1, 8), Pexprand(0.0001, 0.25)).asStream.value,
			\fed, Pexprand(0.00001, 2000.0).asStream.value,
			\amp, Pdup(Pexprand(1, 5), Pexprand(0.75, 2.0)).asStream.value,
			\rel, Pexprand(Pkey(\dur) / (4/3), Pkey(\dur) * 64).asStream.value.poll,
			\pan, Pdup(Pexprand(1, 7), Pseq([0.5, 0.75, 1.0, 0.75, 0.5, 0.25, 0.0, 0.25], 1)).asStream.value,
			\legato, Pwrand([Pkey(\dur) * 1.5, Pkey(\dur) * 16], [1, 2].normalizeSum, 1).asStream.value,
			\sustain, Pdup(Pexprand(1, 3), Pexprand(0.1, 2.0)).asStream.value * 2,
			\out, ~srcMixerChannel.asBus
		] ,target: ~srcMixerChannel.asTarget);
	});
}, '/gyro_read');


OSCdef(\resetButton, {
	arg msg;
	defer {
		knobX.value_(0).doAction;
		knobY.value_(0).doAction;
		knobZ.value_(0).doAction;
		knobLpf.value_(0.5).doAction;
		knobReso.value_(0.5).doAction;
	};
}, '/button_reset')
);
