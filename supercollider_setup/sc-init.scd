// [1]
(
s.quit;
MIDIClient.init;
// s.options.outDevice = "Scarlett 2i4 USB";
// s.options.outDevice ="MacBook Pro Speakers";
// s.options.outDevice ="BlackHole 16ch";
s.options.numInputBusChannels = 0;
s.options.numOutputBusChannels = 4;
s.boot;

s.waitForBoot{
  var windowView=Window("t", Rect(600, 800, 268, 374), border: true, scroll: true).front;
  s.plotTreeView(parent: windowView);
  a = ArturiaBeatStep();
	~sampler_engine = MeMaSEngine("/Users/karnpaponboonput/Desktop/codes/MeMas/mapping_sounds/");
	// ~sampler_engine = MeMaSEngine("/Users/karnpaponboonput/Desktop/samples/soundpharm/FoleyPerc - Loops/");
}
)

// [2]: 
(
~sampler_engine.loadPreProcessedData("/Users/karnpaponboonput/Desktop/codes/MeMas/mapping_sounds_data");
)

// test data
// ~sampler_engine.loadPreProcessedData("/Users/karnpaponboonput/Desktop/test-pref-data");


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
}).add;
)

// [5]: setup mixer (ddwMixerChannel: https://github.com/supercollider-quarks/ddwMixerChannel)
(
s.newBusAllocators;
~srcMixerChannel = MixerChannel(\channel_1, s, 2, 2, 1);
~src2MixerChannel = MixerChannel(\channel_2, s, 2, 2, 1);
~src3MixerChannel = MixerChannel(\channel_3, s, 2, 2, 1);
~src4MixerChannel = MixerChannel(\channel_4, s, 2, 2, 1);
~reverbMixerChannel = MixerChannel(\channel_fx_rvb, s, 2, 2, level: 1,
	completionFunc: { |chan|
		~rvb = chan.playfx { |outbus, revtime=0.8|
			var sig = In.ar(outbus, 2);
      var freez = TRand.kr(-1, 1, Dust.kr(0.7));
      // var revtime = 0.8;
      var drywet = 1;
      var damping = 0.3;
      MiVerb.ar(sig, revtime, drywet, damping, freeze: freez)
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

// (
// ~srcMixerChannel.free;
// ~src2MixerChannel.free;
// ~src3MixerChannel.free;
// ~src4MixerChannel.free;
// ~reverbMixerChannel.free;
// ~delayMixerChannel.free;
// )
// ~reverbMixerChannel.free;

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
	|outbus,in, cutoff = 0, resonance = 0|
	var numChannels = 2;
	var sig = In.ar(outbus, numChannels);
	var cutoffClipped = cutoff.linexp(0.0, 1.0, 40, 20000);
	sig = RLPF.ar(sig, cutoffClipped, resonance.linexp(0, 1, 1, 0.001));
});

~clouds = ~srcMixerChannel.playfx({
  |outbus, pitch=0, mode=0, freeze=0, dry=0, amp=1|
  var sig;
	// var position = LFNoise1.kr(0.5,0.5,0.5);
	var dens = LFNoise1.kr(0.3).range(0.3, 0.45);
  sig = In.ar(outbus, 2);
  sig = MiClouds.ar(sig, pitch, 0, 0.1, 1, 0.5, drywet: dry, freeze: freeze, mode: mode, mul: amp);
  ReplaceOut.ar(outbus, sig);
});

~freqshift = ~src4MixerChannel.playfx({
  |outbus, drywet=0, freq=0.5|
  var in = In.ar(outbus, 2);
  var sig = FreqShift.ar(in, freq: freq.linexp(0.0, 1.0, 40, 4000), phase: 0);
  XOut.ar(outbus, drywet, sig)
});

~pitchshift = ~src4MixerChannel.playfx({
  |outbus, drywet=0, shift=1, size=0.2|
  var dry = In.ar(outbus, 2);
  var sig;
  sig = PitchShift.ar(in: dry,
      windowSize: 0.25, //drywet.linlin(0.0, 1.0, 0.01, 0.4),
      pitchRatio: shift.linlin(0.0, 1.0, 0.01, 2.0),
      pitchDispersion: drywet.linlin(0.0, 1.0, 0.1, 1.0),
      timeDispersion: 0);
  XOut.ar(outbus, drywet, sig)
});

~lpf2 = ~src4MixerChannel.playfx({
  |outbus, cutoff=1|
   var sig = LPF.ar(In.ar(outbus, 2), cutoff.linexp(0.0, 1.0, 40, 20000));
  ReplaceOut.ar(outbus, sig)
});
)


// ----------------Mixer----------------
~board = MixingBoard("x", nil,~srcMixerChannel, ~src2MixerChannel, ~src3MixerChannel, ~src4MixerChannel, ~reverbMixerChannel, ~delayMixerChannel );

// ---------------MeMasEngine-----------
// inject GUI and then start engine.
(
var kNearest, kNearestDist;
var buttonValue="OSC";

w = Window("MeMas",Rect(0,0,600,480+(20*2)+20 ), resizable: false, border: true).front;
w.view.decorator = FlowLayout(w.view.bounds);
// w.alpha_(0.6);
~sampler_engine.controller(parent: w);

// inject out_target to MyLivePerformance lib.
~sampler_engine.external_mixer_(~src4MixerChannel);

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

// -------------tasks-------------------

m = NetAddr("127.0.0.1", NetAddr.langPort);

(
var count = 0;
var inc = 0;
Tdef(\sine_task, {
	loop({
		var x = 0.5;
		var y = cos(count).linlin(-1,1,0,1) * 0.25;
		m.sendMsg("/test_plotter/1",x, y+0.5);
		count = ( count + (2pi/(64*4)) );
		0.01.wait
	})
});
)

Tdef(\sine_task).stop;
Tdef(\sine_task).play(quant: 4);

// ----------------MPU6050---------------
(
var resetBtn, knobX, knobY, knobZ, knobLpf, knobReso, knobFreqShiftFreq, knobLpf2, knobPitchShift, knobPitchShiftSize, knobFreqShiftDryWet, knobPitchShiftDryWet, knobReverbTime;
var knobs;
w=Window("k", Rect(1200, 800, 312, 375), border: true, scroll: true).front;
w.view.decorator = FlowLayout( w.view.bounds, 10@10, 20@5 );

knobX=EZKnob(w,80@90,"dst",ControlSpec(0, 1, \lin, 0.01, 0), {|ez|
  ~dist.set(\dst, ez.value);
}, layout: "vert2".asSymbol);

knobY=EZKnob(w,80@90,"tri",ControlSpec(0, 1, \lin, 0.01, 0), {|ez|
	// var knobVal = (ez.value).linlin(0,127,0,1);
	// ~triode.set(\tri, knobVal);
  ~triode.set(\tri, ez.value);
}, layout: "vert2".asSymbol);
knobZ=EZKnob(w,80@90,"shape_lo",ControlSpec(0, 1, \lin, 0.01, 0), {|ez|
	// var knobVal = (ez.value).linlin(0,127,0,1);
	// ~shaper.set(\lo, knobVal);
  ~shaper.set(\lo, ez.value);
}, layout: "vert2".asSymbol);

knobLpf=EZKnob(w,80@90,"cutoff",ControlSpec(0, 1, \lin, 0.01, 0), {|ez|
	~lpf.set(\cutoff, ez.value);
}, layout: "vert2".asSymbol);

knobReso=EZKnob(w,80@90,"reson",ControlSpec(0, 1, \lin, 0.01, 0), {|ez|
	~lpf.set(\resonance, ez.value);
}, layout: "vert2".asSymbol);

knobLpf2=EZKnob(w,80@90,"lpf2",ControlSpec(0, 1, \lin, 0.01, 1), {|ez|
	~lpf2.set(\cutoff, ez.value);
}, layout: "vert2".asSymbol);

knobFreqShiftDryWet=EZKnob(w,80@90,"freqdry",ControlSpec(0, 1, \lin, 0.01, 0), {|ez|
	~freqshift.set(\drywet, ez.value);
}, layout: "vert2".asSymbol);

knobFreqShiftFreq=EZKnob(w,80@90,"freq",ControlSpec(0, 1, \lin, 0.01, 0), {|ez|
	~freqshift.set(\freq, ez.value);
}, layout: "vert2".asSymbol);

knobPitchShiftDryWet=EZKnob(w,80@90,"pitchdry",ControlSpec(0, 1, \lin, 0.01, 0), {|ez|
	~pitchshift.set(\drywet, ez.value);
}, layout: "vert2".asSymbol);

knobPitchShift=EZKnob(w,80@90,"shift",ControlSpec(0, 1, \lin, 0.01, 1), {|ez|
	~pitchshift.set(\shift, ez.value);
}, layout: "vert2".asSymbol);

knobPitchShiftSize=EZKnob(w,80@90,"size",ControlSpec(0, 1, \lin, 0.01, 0.2), {|ez|
	~pitchshift.set(\size, ez.value);
}, layout: "vert2".asSymbol);

knobReverbTime=EZKnob(w,80@90,"revtime",ControlSpec(0, 1, \lin, 0.01, 0.8), {|ez|
	~rvb.set(\revtime, ez.value);
}, layout: "vert2".asSymbol);


knobs = [knobX, knobY, knobZ, knobLpf, knobReso, knobLpf2, knobFreqShiftDryWet, knobFreqShiftFreq, knobPitchShiftDryWet, knobPitchShift, knobPitchShiftSize, knobReverbTime];


OSCdef(\coordChanged, {
	arg msg;
	// msg.postln;
	// defer {
	// 	knobX.value_(if(msg[1] == 0, 0, (msg[1])*2)).doAction;
	// 	knobY.value_(if(msg[2].neg == 0, 0, (127-(msg[2].neg))*2.5)).doAction;
	// 	knobZ.value_(if(msg[3].neg == 0, 0, (127-(msg[3].neg))*2.5)).doAction;
	// };

	if(msg[1] != 0 && ((msg[1] % 40)==0), {
		Synth(\drm, [
			\dur, 1 / Pwrand([5, 10], [3, 8].normalizeSum, 1).asStream.value * 2,
			\tun, Pdup(Pexprand(1, 8), Pexprand(0.0001, 0.25)).asStream.value,
			\fed, Pexprand(0.00001, 2000.0).asStream.value,
			\amp, Pdup(Pexprand(1, 5), Pexprand(0.75, 2.0)).asStream.value,
			\rel, Pexprand(Pkey(\dur) / (4/3), Pkey(\dur) * 64).asStream.value,
			\pan, Pdup(Pexprand(1, 7), Pseq([0.5, 0.75, 1.0, 0.75, 0.5, 0.25, 0.0, 0.25], 1)).asStream.value,
			\legato, Pwrand([Pkey(\dur) * 1.5, Pkey(\dur) * 16], [1, 2].normalizeSum, 1).asStream.value,
			\sustain, Pdup(Pexprand(1, 3), Pexprand(0.1, 2.0)).asStream.value * 2,
			\out, ~srcMixerChannel.asBus
		] ,target: ~srcMixerChannel.asTarget);
	});
}, '/sc_kick');

a.knobs.do { |knob,i|
  knob.onChange = {|val|
    if(i<=11,{
      defer{ knobs[i].value_(val/127).doAction; };
    },{});
  };
};

a.pads.at(0).onPress = { ~clouds.set(\freeze, 1); };
a.pads.at(0).onRelease = { ~clouds.set(\freeze, 0); };

	// defer {
 		// knobX.value_(c.knobs.at(1).asMap).doAction;
 		// knobY.value_(0).doAction;
 		// knobZ.value_(0).doAction;
 		// knobLpf.value_(0.5).doAction;
 		// knobReso.value_(0.5).doAction;
 	// };


resetBtn = Button(w, Rect(20, 40, 80, 30))
  .states_([ 
    ["reset"] 
  ])
  .action_({
  |butt|
	knobX.value_(0).doAction;
	knobY.value_(0).doAction;
 	knobZ.value_(0).doAction;
 	knobLpf.value_(0).doAction;
 	knobReso.value_(0).doAction;
  knobFreqShiftFreq.value_(0).doAction;
  knobLpf2.value_(1).doAction;
  knobPitchShift.value_(1).doAction;
  knobPitchShiftSize.value_(0.2).doAction;
  knobFreqShiftDryWet.value_(0).doAction;
  knobPitchShiftDryWet.value_(0).doAction;
  knobReverbTime.value_(0.8).doAction;
})

);

s.scope
