// 0
(
Ndef(\0, {|freqMin=5, freqMax=10, mul=20, add=80, rate=0.5, modFreq=2100, index=0.3, amp=1|
	var trig, seq, freq, sig;
	trig = Impulse.kr(rate);
	seq = Diwhite(freqMin, freqMax, inf).midicps;
	freq = Demand.kr(trig, 0, seq);
	HPF.ar(PMOsc.ar(LFCub.kr([freq, freq/2], 0, mul, add), modFreq, index) * 0.4 * amp, 30)
})
)

Ndef(\0).set(\modFreq, 400);
Ndef(\0).release;
Ndef(\0).fadeTime_(4)
Ndef(\0).group_(~src3MixerChannel.synthgroup)
Ndef(\0).setBus(~src3MixerChannel.asBus)



// 1
(
Ndef(\1, {|nf=3, sf=0.0007, hpf=20000|
	HPF.ar(OFNanite.ar(nf, surface:sf, freqShift:50.neg),
) * 2 });
)

Ndef(\1).group_(~src3MixerChannel.synthgroup)
Ndef(\1).setBus(~src3MixerChannel.asBus)
Ndef(\1).release;
Ndef(\1).fadeTime_(4);


// 2
(
Ndef(\2, { |freq=90, modFreq=11, harms=150|
	var son = Splay.ar ( HPF.ar(Blip.ar( Array.series(4, freq, 5), harms).fold2(
		SinOsc.ar(Array.series(4, modFreq, modFreq/2))), 30)) * 0.6;
	son = BBandStop.ar(son, LFNoise1.ar(1).exprange(100, 8000), 8);
	LPF.ar(son, 12000)
});
)

s.sendMsg(11, 2175)

Ndef(\2).release;
Ndef(\2).xset(\freq, 300)
Ndef(\2).set(\freq, 100)
Ndef(\2).fadeTime_(4)
Ndef(\2).group_(~src3MixerChannel.synthgroup)
Ndef(\2).setBus(~src3MixerChannel.asBus)


// 3 ????
(
Ndef(\3, {
	var signal;
	signal = DemandEnvGen.ar(
		Dseq([-1, 0.1,  Dwhite(-0.1, 0.1, 5), Dwhite(-0.2, 0.2, 5)], inf),
		SampleDur.ir * 1.1, 1, 0,  1, Impulse.ar([10, 40]))
	* XLine.ar(0.001, 0.1, 10) * EnvGen.ar(Env([0,1,1,0],[1,22,14], 'sine'));
	BPeakEQ.ar(signal, 10000, 4, EnvGen.ar(Env([0, -1, -7], [4, 12])));
});
)

Ndef(\3).release;
Ndef(\3).xset(\freq, 300)
Ndef(\3).set(\freq, 100)
Ndef(\3).fadeTime_(4)
Ndef(\3).group_(~src3MixerChannel.synthgroup)
Ndef(\3).setBus(~src3MixerChannel.asBus)



//4
(
Ndef(\4, {|freq=66, mod=8, amp=1.0|
		PMOsc.ar(freq, OFDinocap.ar(mod).range(10,100), 1.1) * 0.25 * amp
	})
)

Ndef(\4).release;
Ndef(\4).xset(\freq, 52)
Ndef(\4)[1] = \xset -> Pbind(
  \freq, (Pseq([40, 45,54, 46], 4)),
)

Ndef(\4).xset(\mod, 12)
Ndef(\4).fadeTime_(1)
Ndef(\4).group_(~src3MixerChannel.synthgroup)
Ndef(\4).setBus(~src3MixerChannel.asBus)


//5
Ndef(\5).release;
Ndef(\5).fadeTime_(1)
Ndef(\5).group_(~src3MixerChannel.synthgroup)
Ndef(\5).setBus(~src3MixerChannel.asBus)
Ndef(\5).gui;

(
Ndef(\5, {
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
});
)


// 6
(
Ndef(\6, {
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
});
)

// 7
(
Ndef(\osom, {|rate=2, trigMin=0.01, trigMax=10, shift=0.02, decay=0.1, initx=0.3, inity=0.1, initz=0.2, freq=600, bw=8, amp=1|
		var trigx = Impulse.kr(rate);
		var seqx = Diwhite(trigMin, trigMax, inf).midicps;
		var trig = Demand.kr(trigx, 0, seqx);
		var signal = Splay.ar(BBandStop.ar( Oregonator.ar(
			Impulse.kr(trig), shift, decay, 0.1, 0.2,initx:initx, inity:inity.neg, initz:initz),
		freq, bw, amp * 1.4));
		signal = HPF.ar(signal, 40);
	})
)

