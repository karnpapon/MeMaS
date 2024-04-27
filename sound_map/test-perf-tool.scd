// ------------------------------------------------------------------------------------------------
// this section will go through evey processes.
// that being said, if you have many sample files the processing time will takes up quite sometime to finish.
// especially with `.analyze` and `.map_dataset` function.
// the recommended way is do this once and then `exportProcessedData`
// so we can read pre-computed information later. see [1] for an example.
p = MyLivePerformanceTool("/Users/karnpaponboonput/Desktop/samples/soundpharm/FoleyPerc - Loops/");
// a = MyLivePerformanceTool("/Users/karnpaponboonput/Desktop/samples/soundpharm/test/");
// a = MyLivePerformanceTool(FluidFilesPath());

p.analyze;
p.map_dataset;

(
p.normalize;
p.map_kd_tree(0.01);
)

p.plot;

(
p.listen;
p.controller;
)

// optional
a.exportProcessedData("/Users/karnpaponboonput/Desktop/live-perf-data/", "my-live-perf-data");
// ------------------------------------------------------------------------------------------------


// ------------------------------------------------------------------------------------------------
// [1]
// for loading preProcessed data (slicing/analysing/map_data_set/normalize/map_kdtree).
// dont forget to `exportProcessedData` first.
p = MyLivePerformanceTool("/Users/karnpaponboonput/Desktop/samples/soundpharm/FoleyPerc - Loops/");
p.loadPreProcessedData("/Users/karnpaponboonput/Desktop/live-perf-data");

p.plot
p.listen;
(
p.listen;
p.controller;
)

// ------------------------------------------------------------------------------------------------

(
SynthDef("kick", {arg out = 0, amp = 1, sinfreq = 100, glissf = 0.1, att = 0.01, rel = 1, pan = 0;
	var env, snd, ramp;
	env = Env.perc(att, rel, amp).kr(doneAction: 2);
	ramp = XLine.kr(
		start: sinfreq,
		end: sinfreq * glissf,
		dur: rel
	);
	snd = SinOsc.ar(freq: ramp, mul: env);
	snd = Pan2.ar(snd, pan);
	Out.ar(out, snd);
}).add;

SynthDef("snare", {arg out = 0, amp = 0.1, sinfreq = 180, att = 0.01, rel = 0.2, ffreq = 2000, pan = 0;
	var env, snd1, snd2, sum;
	env = Env.perc(att, rel, amp).kr(doneAction: 2);
	snd1 = HPF.ar(
		in: WhiteNoise.ar,
		freq: ffreq,
		mul: env
	);
	snd2 = SinOsc.ar(freq: sinfreq, mul: env);
	sum = snd1 + snd2;
	Out.ar(out, Pan2.ar(sum, pan));
}).add;

SynthDef("sawSynth", { arg freq = 540, amp = 0.1, att = 0.1, rel = 2, lofreq = 1000, hifreq = 3000;
    var env, snd;
    env = Env.perc(
		attackTime: att,
		releaseTime: rel,
		level: amp
	).kr(doneAction: 2);
    snd = Saw.ar(freq: freq * [0.99, 1, 1.001, 1.008], mul: env);
	snd = LPF.ar(
		in: snd,
		freq: LFNoise2.kr(1).range(lofreq, hifreq)
	);
    snd = Splay.ar(snd);
    Out.ar(0, snd);
}).add;

SynthDef(\gabberkick, {
    var snd;
    snd = SinOsc.ar(Env([1000, 69, 60], [0.015, 0.1], \exp).ar * [-0.1, 0, 0.1].midiratio);
    snd = Mix(snd);
    snd = (snd * 10).tanh;
    snd = (snd * 5.1).atan;
    snd = BPeakEQ.ar(snd, XLine.kr(2000, 100, 0.3), 2.0, 8);
    snd = snd + DelayC.ar(snd, 0.01, SinOsc.ar(4).range(0.0, 0.001));
    snd = RLPF.ar(snd, 8000, 0.7);
    snd = snd * Env([0, 1, 0.7, 0.7, 0], [0.001, 0.01, 0.3, 0.02]).ar(2);
    snd = (snd * 0.6).clip(-1, 1);
    Out.ar(\out.kr(0), Pan2.ar(snd, \pan.kr(0), \amp.kr(0.1)));
}).add;

)


Synth("kick");
Synth("snare");

Synth(\gabberkick);

Synth("sawSynth", [\freq, 330]);

(
OSCdef(\bounce_wall_y, {
	|msg, time, addr, recvPort|
	Synth(\gabberkick);
}, '/bounce_wall/y');


OSCdef(\bounce_wall_x, {
	|msg, time, addr, recvPort|
	Synth(\gabberkick);
}, '/bounce_wall/x');
)


(
OSCdef(\bounce_wall_y).clear;
OSCdef(\bounce_wall_x).clear;
)
