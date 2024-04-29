(
Ndef(\nanite, {|nf=3, sf=0.0007, hpf=20000|
	HPF.ar(OFNanite.ar(nf, surface:sf, freqShift:50.neg),
		EnvGen.ar(Env([19900,100,300,8000,18000],[0.2,22,14,22], 'sine'))
) * 2 }).play;
)


OFDinocap.ar(freq: 90).play


(
Ndef(\bromate, {
	arg freq=100, modFreq=2.1, mul=1.0, add=0.0;
	var saw = LeastChange.ar(GbmanL.ar(freq, freq * 1.3).clip(LFNoise2.ar([modFreq, modFreq*1.1])), GbmanL.ar(freq*1.3));
	var band = BBandStop.ar(saw, LFNoise2.kr(freq/100, freq, freq * 4), 10);
	Splay.ar(LPF.ar(HPF.ar(band, 110), 15000)) * 0.25;
}).play
)

(
Ndef(\silk, {
	|freq=1090, amp=1.0, harms=170, modFreq=9, modFreq2=1, modFreq3=3.1|
	var mod = SinOsc.ar(LFNoise2.kr(modFreq2).range(modFreq * 5, 0.5), 0, LFNoise1.kr(modFreq/10).range(5, 20));
	var sig = Splay.ar(Blip.ar(Array.series(5, freq, freq/24) + mod, harms));
	sig = BPeakEQ.ar(BBandStop.ar(sig, harms * 10, 2.5), LFNoise1.kr(modFreq, 3500, 8000), 1, -10) * 2;
	Splay.ar(sig * LFNoise1.ar(modFreq3).range(0.3,1.1) * amp)
}).play
)

Ndef(\depfm).gui
Ndef(\silk).clear

(
Ndef(\vsaw, {|freq=90, amp=1.0, modFreq=0.5, ampMod=0.8, bsMul=600, bsAdd=800, bsBw=8|
		var sig = VarSaw.ar(LFPar.ar(freq/[10,8], 0, 10, LFPar.kr(5, 0, 5, freq)), 0, LFNoise2.kr(freq/3, 0.5, 1.5)) * 0.6;
		var thres = Lag.kr(Amplitude.kr(sig), 0.1);
		var osc = Splay.ar(Pulse.ar(Array.series(10, freq, 5))) * thres;
		sig = osc + BPeakEQ.ar(BBandStop.ar(sig, LFNoise1.kr(modFreq, bsMul, bsAdd), bsBw), 80, 3, -2);
 		HPF.ar(Splay.ar(sig),60,amp) * LFNoise1.ar(ampMod).range(0.3,1.1)
	}).play
)


(
Ndef(\osom, {|rate=2, trigMin=0.01, trigMax=10, shift=0.02, decay=0.1, initx=0.3, inity=0.1, initz=0.2, freq=600, bw=8, amp=1|
		var trigx = Impulse.kr(rate);
		var seqx = Diwhite(trigMin, trigMax, inf).midicps;
		var trig = Demand.kr(trigx, 0, seqx);
		var signal = Splay.ar(BBandStop.ar( Oregonator.ar(
			Impulse.kr(trig), shift, decay, 0.1, 0.2,initx:initx, inity:inity.neg, initz:initz),
		freq, bw, amp * 1.4));
		signal = HPF.ar(signal, 40);
	}).play
)

(
Ndef(\demwi, {|rate=3, trigMin=18, trigMax=20, times=10, delay=0.05, decay=0.5, amp=1.0|
		var trigx = Impulse.kr(rate);
		var seqx = Diwhite(trigMin, trigMax, inf).midicps;
		var trig = Demand.kr(trigx, 0, seqx);
		var snd = HPF.ar(BPeakEQ.ar(
			OFDemWhite.ar(1).tanh(
			SinOsc.ar(trig)),
			LFNoise1.ar(2).range(80,6000ss),
			LFNoise1.ar(3).range(2,8),
			LFNoise1.ar(32).range(-4,-12)), 40);

		Mix.fill(10, { CombC.ar(snd.tanh * amp, delay, rrand(delay/1, delay), decay) * 1/times});
	}).play
)


Ndef(\depfm).free
// + (1)
(
Ndef(\depfm, {|freqMin=5, freqMax=10, mul=20, add=80, rate=0.5, modFreq=2100, index=0.3, amp=0.5|
	var trig, seq, freq;
	trig = Impulse.kr(rate);
	seq = Diwhite(freqMin, freqMax, inf).midicps;
	freq = Demand.kr(trig, 0, seq);
	HPF.ar(PMOsc.ar(LFCub.kr([freq, freq/2], 0, mul, add), modFreq, index) * 0.4 * amp, 30)
}).play
)

Ndef(\depfm).fadeTime_(1.5)
Ndef(\depfm).xset(\modFreq, 2500, \freqMax, 10, \freqMin, 3)
Ndef(\depfm).gui

(
Ndef(\bloded, { |freq=90, modFreq=11, harms=150|
	var son = Splay.ar ( HPF.ar(Blip.ar( Array.series(4, freq, 5), harms).fold2(
		SinOsc.ar(Array.series(4, modFreq, modFreq/2))), 30)) * 0.6;
	son = BBandStop.ar(son, LFNoise1.ar(1).exprange(100, 8000), 8);
	LPF.ar(son, 12000)
}).play;
)


Ndef(\bloded).fadeTime_(1.5)
Ndef(\bloded).xset(\freq, 120, \modFreq, 20)
Ndef(\bloded).clear

(
Ndef(\demwav, {
	var signal;
	signal = DemandEnvGen.ar(
		Dseq([-1, 0.1,  Dwhite(-0.1, 0.1, 5), Dwhite(-0.2, 0.2, 5)], inf),
		SampleDur.ir * 1.1, 1, 0,  1, Impulse.ar([10, 40]))
	* XLine.ar(0.001, 0.1, 10) * EnvGen.ar(Env([0,1,1,0],[1,22,14], 'sine'));
	BPeakEQ.ar(signal, 10000, 4, EnvGen.ar(Env([0, -1, -7], [4, 12])));
}).play;
)

(
Ndef(\fmdin, {|freq=66, mod=8, amp=1.0|
		PMOsc.ar(freq, OFDinocap.ar(mod).range(10,100), 1.1) * 0.25 * amp
	}).play
)

Ndef(\fmdin).gui


(
Ndef(\nanite, {|nf=3, sf=0.007, hpf=20000|
	HPF.ar(OFNanite.ar(nf, surface:sf, freqShift:10.neg),
		EnvGen.ar(Env([19900,100,300,8000,18000],[0.2,22,14,22], 'sine'))
) * 1.5 }).play;
)


Ndef(\opca).fadeTime_(1.2)

(
Ndef(\opca, {
 var sdm=1, size = 5, from=1, to=25,modFreq=10,modFrom=2,modTo=255, amp=0.25;
 var trig, waveform;
 var sd = SampleDur.ir * sdm;
var rand = Array.rand(size,from,to);
	rand.postln;
 waveform = DemandEnvGen.ar(
		Dseq([1, [-1,0.5]], inf),
		Dseq(rand, inf) * sd
	).atan(SinOsc.ar(LFNoise0.ar(modFreq).range(modFrom, modTo)));
	Splay.ar(waveform * amp);
}).play
)

Ndef(\hectn).gui

Ndef(\opca).free


// +
(
Ndef(\hectn, {
	|sdm=0.15,modFreq=10, modFrom=5, modTo=25, fmfreq=100, fmhi=4000, amp=0.25, mf = 0.25|
	var size = 5, from=1, to=25;
	var sd = SampleDur.ir * sdm;
	var first = [1, [-1, 1.0]];
	var second = Array.rand(size,from,to);
	var seq = Dseq(second, inf);
	var snd = DemandEnvGen.ar(Dseq(first, inf), seq * sd
	).atan(SinOsc.ar(LFNoise0.ar(modFreq).range(modFrom, modTo))) * 0.5;

	var trig = Impulse.kr(10);
	var freq = Demand.kr(trig, 0, seq);
	var buena = Stepper.kr(trig, 0, 0, 10, 1);

	snd = snd + PMOsc.ar(LFCub.kr([freq, freq/2], 0, fmfreq * 0.2, fmfreq), fmhi, 0.5) * mf;
	snd = snd + (DemandEnvGen.ar(Dwhite(-0.9,0.9,1),seq * sd * 10 * 0.1));
	HPF.ar(snd, 40, amp);
	Splay.ar(snd * amp);
}).play;
)
