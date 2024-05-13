(

Window.closeAll;
MIDIClient.init;
// s.options.outDevice = "Scarlett 2i4 USB";
// s.options.outDevice = "Audient iD14";
s.options.outDevice ="MacBook Pro Speakers";
s.options.numInputBusChannels = 0;

s.waitForBoot{
	var synth, multislider, win, xyslider;
	var xydata = FluidDataSet(s);
	var paramsdata = FluidDataSet(s);
	var xybuf = Buffer.alloc(s,2);
	var paramsbuf = Buffer.alloc(s,10);
	var counter = 0;
	var window_w = 960;
	var mlp_cached_path = "";
	var basename = 'nano_';
	var numChans = 2;
	var lagtime = 0.1;

	// multi-layer perceptron
	var mlp = FluidMLPRegressor(s,
		[7],
		activation:FluidMLPRegressor.sigmoid,
		outputActivation:FluidMLPRegressor.sigmoid,
		maxIter: 1000,
		learnRate:0.1,
		batchSize:1,
		validation:0
	);

	win = Window("GhostSynth", Rect(0, 0, 960-220, 212)).front;
	multislider = MultiSliderView(win,Rect(10, 10, 400-100, (720*0.45)-130))
	.elasticMode_(1)
	.isFilled_(1)
	.action_({
		arg ms;
		paramsbuf.setn(0,ms.value);
	})
	.value_(0.5.dup(10));

	xyslider = Slider2D(win,Rect(420-100,10,(1280*0.3) - 100,(720*0.45)-130 ))
	.action_{
		arg view;
		// view.x.postln; //top-left: 0, bottom-right: 1
		// view.y.postln; //top-left: 1, bottom-right: 0
		xybuf.setn(0,[view.x,view.y]);
	};

	Button(win,Rect(window_w - 340,10,100,20))
	.states_([["Add Points"]])
	.action_{
		var id = "point-%".format(counter);
		xydata.addPoint(id,xybuf);
		paramsdata.addPoint(id,paramsbuf);
		counter = counter + 1;

		xydata.print;
		paramsdata.print;
	};

	Button(win,Rect(window_w - 340,35,100,20))
	.states_([["Save Data"]])
	.action_{
		FileDialog({
			arg folder;
			xydata.write(folder+/+"xydata.json");
			paramsdata.write(folder+/+"paramsdata.json");
		},{},2,0,true);
	};

	Button(win,Rect(window_w - 340,60,100,20))
	.states_([["Load Data"]])
	.action_{
		FileDialog({
			arg folder;
			xydata.read(folder+/+"xydata.json");
			paramsdata.read(folder+/+"paramsdata.json");
		},fileMode:2,acceptMode:0,stripResult:true);
	};

	Button(win,Rect(window_w - 340,85,100,20))
	.states_([["Train"]])
	.action_{
		mlp.fit(xydata,paramsdata,{
			arg loss;
			loss.postln;
		});
	};

	Button(win,Rect(window_w - 340,110,100,20))
	.states_([["Save MLP"]])
	.action_{
		Dialog.savePanel({
			arg path;
			if(PathName(path).extension != "json"){
				path = "%.json".format(path);
			};
			mlp.write(path);
		});
	};

	Button(win,Rect(window_w - 340,135,100,20))
	.states_([["Load MLP"]])
	.action_{
		Dialog.openPanel({
			arg path;
			mlp.read(path);
			mlp_cached_path = path;
		});
	};

	Button(win,Rect(window_w - 340,160,100,20))
	.states_([["Not Predicting"],["Predicting"]])
	.action_{
		arg but;
		but.value.postln;
		~synth.set(\predicting,but.value);
	};

	Button(win,Rect(window_w - 340,185,100,20))
	.states_([["Play"], ["Pause"]])
	.action_{
		arg but;
		if (but.value == 1, {
			~synth = Synth(basename ++ 'main_synth');
			if ( mlp_cached_path != "", { mlp.read(mlp_cached_path); },{});
		}, { ~synth.free; });
	};

	s.sync;

	(
		SynthDef.new(basename ++ 'main_synth', {
			arg predicting = 0, mod_base1=1, mod_base2=1, mod_base3=1;
			var osc1, osc2, feed1, feed2, base1=69, base2=69, base3 = 130, loud1, loud2;
			var val, xy, trig;

			xy = FluidBufToKr.kr(xybuf);
			trig = Mix(Changed.kr(xy));
			mlp.kr(trig * predicting,xybuf,paramsbuf);
			val = FluidBufToKr.kr(paramsbuf);
			SendReply.kr(Mix(Changed.kr(val)),"/paramsChanged",val);

			#feed2, feed1 = LocalIn.ar(2);

			loud1 = FluidLoudness.kr(feed1,[\loudness],1,0,hopSize:64);
			loud2 = FluidLoudness.kr(feed2,[\loudness],1,0,hopSize:64);

			osc1 = SinOsc.ar((((feed1 * val[0]) +  val[1]) * base1 * mod_base1).midicps,mul:(val[2] * 50).dbamp).atan;
			osc1 = MoogFF.ar(osc1,(( base3 * mod_base3 )-(val[3]*(loud2.clip(-120,0)+120))).lag(128/44100).midicps,val[4]*3.5);

			osc2 = SinOsc.ar((((feed2 * val[5]) +  val[6]) * base2 * mod_base2).midicps,mul: (val[7] * 50).dbamp).atan;
			osc2 = MoogFF.ar(osc2,(base3-(val[8]*(loud1.clip(-120,0)+120))).lag(128/44100).midicps,val[9]*3.5);

			Out.ar(0,LeakDC.ar([osc1,osc2],mul:0.1));
			LocalOut.ar([osc1,osc2]);
		}).add;

		SynthDef(basename ++ 'amp', {|envatt = 0.01, envrel = 0.01, bus, outbus|
			var sig = In.ar(bus, numChans).sum;
			sig = Amplitude.kr(sig, envatt, envrel);
			Out.kr(outbus, sig);
		}, lagtime.dup(2)).add;


		SynthDef(basename ++ 'low_amp', {|envatt = 0.01, envrel = 0.01, bus, outbus|
			var sig = In.ar(bus, numChans).sum;
			sig = LPF.ar(sig, 250);
			sig = Amplitude.kr(sig, envatt, envrel);
			Out.kr(outbus, sig);
		}, lagtime.dup(2)).add;

		SynthDef(basename ++ 'high_amp', {|envatt = 0.01, envrel = 0.01, bus, outbus|
			var sig = In.ar(bus, numChans).sum;
			sig = HPF.ar(sig, 1500);
			sig = Amplitude.kr(sig, envatt, envrel);
			Out.kr(outbus, sig);
		}, lagtime.dup(2)).add;

		SynthDef(basename ++ 'lpf' , {|cutoff = 1, bus|
			var sig = LPF.ar(In.ar(bus, numChans), cutoff.linexp(0.0, 1.0, 40, 20000));
			ReplaceOut.ar(bus, sig)
		}, lagtime).add;

		SynthDef(basename ++ 'hpf' , {|cutoff = 1, bus|
			var sig = HPF.ar(In.ar(bus, numChans), cutoff.linexp(0.0, 1.0, 20000, 40));
			ReplaceOut.ar(bus, sig)
		}, lagtime).add;

		SynthDef(basename ++ 'comp' , {|slopeBelow = 1, bus|
			var sig = In.ar(bus, numChans);
			sig =  Compander.ar(sig, sig,
				thresh: 0.9,
				slopeBelow: slopeBelow,
				slopeAbove: 0.5, // Ratio, 1/3 == 3: 1
				clampTime:  0.01,
				relaxTime:  0.1
			);
			ReplaceOut.ar(bus, sig)
		}, lagtime).add;

		SynthDef(basename ++ 'eq' , {|loBoost = 0, hiBoost = 0, q = 0.3, hiFreq = 3000,  loFreq = 250, bus|
			var sig = In.ar(bus, numChans);
			sig = MidEQ.ar(sig, loFreq, q.linlin(0.0, 1.0, 0.1, 1.0), loBoost.linlin(0.0, 1.0, - 12.0, 12.0));
			sig = MidEQ.ar(sig, hiFreq, q.linlin(0.0, 1.0, 0.1, 1.0), hiBoost.linlin(0.0, 1.0, - 12.0, 12.0));
			ReplaceOut.ar(bus, sig)
		}, lagtime.dup(5)).add;

		SynthDef(basename ++ 'shape', {
			|out, shape = 0, amp = 1.0,  amp_compensation_amount = 0.99, lo = 1, hi = 0, offset = 0, lo_thresh = 0, hi_thresh = 0|
			var abs, diff;
			var signal = In.ar(out, 2);
			shape = min(shape, 1.0 - 4e-10).explin(0.001, 1, 0.0, 0.999999);
			amp_compensation_amount = amp_compensation_amount.linlin(0.0,1.0,0.0001,1.0);
			amp = 1.0 - (amp_compensation_amount * shape / (shape +amp_compensation_amount )) * amp;
			shape = (1.0 * shape) / (1.0 - shape);
			signal = (1 + shape) * signal / (1 + (shape * abs(signal)));
			offset = offset.linlin(0.0,1.0,1.0,5.0);
			hi = hi * offset; lo = lo * offset;
			abs = hi - lo;
			lo_thresh = lo_thresh.linlin(0.0,1.0,-1.0,1.0);
			lo = lo + (abs * lo_thresh);
			hi_thresh = hi_thresh.linlin(0.0,1.0,-1.0,1.0);
			hi = hi - (abs * hi_thresh);
			signal = Fold.ar(signal, lo, hi);
			diff = 1 - (lo - hi + (hi * lo));
			ReplaceOut.ar(out, Limiter.ar(LeakDC.ar(signal * (amp+diff))));
		}).add;

		SynthDef(basename ++ 'waveloss' , {|drywet = 0, loss = 1, bus|
			var in = In.ar(bus, numChans);
			var sig =  WaveLoss.ar(in, drop: loss.linlin(0.0, 1.0, 0, 10), outof: 10, mode: 2);
			XOut.ar(bus, drywet, sig)
		}, lagtime.dup(4)).add;

		SynthDef(basename ++ 'freqshift' , {|drywet = 0, freq = 0.5, bus|
			var in = In.ar(bus, numChans);
			var sig = FreqShift.ar(in, freq: freq.linexp(0.0, 1.0, 40, 4000), phase: 0);
			XOut.ar(bus, drywet, sig)
		}, lagtime.dup(2)).add;

		SynthDef(basename ++ 'verb', {|time = 1, size = 1, drywet = 0, modDepth = 0.1, bus|
			var sig = In.ar(bus, numChans);
			sig = JPverb.ar(sig, t60: time,
				damp: 1 - drywet,
				size: size.linlin(0.0, 1.0, 0.1, 5.0),
				earlyDiff: modDepth.linlin(0.0, 1.0, 1.0, 0.5),
				modDepth: modDepth.linlin(0.0, 1.0, 0.01, 1.0),
				modFreq: 2,
				lowcut: 500, highcut: 2000);
			XOut.ar(bus, drywet, sig);
		}, lagtime.dup(4)).add;

		SynthDef(basename ++ 'sub', {|freq = 0.5, subamp, drywet = 0, bus|
			var dry = In.ar(bus, numChans);
			var sig = SinOsc.ar(freq.linlin(0.0, 1.0, 40, 120),
				0,
				(subamp * 4).clip(0, 1)
			);
			sig = LPF.ar(sig, 150);
			sig = dry + sig;
			sig = LeakDC.ar(sig);
			XOut.ar(bus, drywet, sig);
		}, lagtime.dup(3)).add;


		SynthDef(basename ++ 'grain', {|grainsize = 0.25, grainrand = 0.8, drywet = 1, fbGain = 0, bus|
			var input = In.ar(bus, numChans);
			var bufLength = 1.0;
			var localBuf = LocalBuf(bufLength * SampleRate.ir, numChans).clear;

			var warp = Warp1.ar(
				numChans,
				localBuf,
				LFSaw.ar(1/bufLength).range(0, 1),
				Drand([ 2, - 2 ], inf),
				grainsize.linlin(0.0, 1.0, 2.0, 0.31),
				- 1,
				2,
				grainrand.linlin(0.0, 1.0, 0.2, 1.0),
				4
			);
			// record w/ feedback
			RecordBuf.ar(tanh(input + HPF.ar(tanh(warp * fbGain), 30)), localBuf);
			warp = warp.tanh;
			warp = HPF.ar(warp * 0.5, 150);
			warp = warp.sanitize;
			XOut.ar(bus, drywet, warp);
		}, lagtime.dup(4)).add;

		SynthDef(basename ++ 'pitchshift', {|drywet = 0, shift = 1, size = 0.2, bus|
			var dry = In.ar(bus, numChans);
			var sig;
			sig = PitchShift.ar(in: dry,
				windowSize: 0.25, //drywet.linlin(0.0, 1.0, 0.01, 0.4),
				pitchRatio: shift.linlin(0.0, 1.0, 0.01, 2.0),
				pitchDispersion: drywet.linlin(0.0, 1.0, 0.1, 1.0),
				timeDispersion: 0);
			XOut.ar(bus, drywet, sig);
		}, lagtime.dup(3)).add;


		SynthDef(basename ++ 'out', {|bus|
			var in = In.ar(bus, numChans);
			// apply limiter
			var sig = Compander.ar(in, in,
				thresh: 0.75,
				slopeBelow: 1,
				slopeAbove: 0.1,
				clampTime:  0.01,
				relaxTime:  0.01
			);
			ReplaceOut.ar(0, sig * 0.5)
		}).add;


	);

	OSCdef(\paramsChanged,{
		arg msg;
		defer{
			multislider.value_(msg[3..]);
		};
	},"/paramsChanged");

	OSCdef(\coordChanged, {
		arg msg;
		msg.postln;
		defer {
			xyslider.setXY(msg[1], msg[2].neg);
			xybuf.setn(0,[msg[1],msg[2]]);
		};
	}, '/gyro_read');
};
)


OSCdef.freeAll

(
var knobX, knobY, knobZ, knobLpf, knobReso;
w=Window("MPU6050", Rect(0, 600, 400, 120)).front;
w.view.decorator = FlowLayout( w.view.bounds, 10@10, 20@5 );

knobX=EZKnob(w,60@90," GYRO_X ",ControlSpec(0, 127, \lin, 1, 0), {|ez|
	var knobVal = (ez.value).linlin(0,127,0,1);
	~dist.set(\dst, knobVal);
	// distVal.postln;
});
knobY=EZKnob(w,60@90," GYRO_Y ",ControlSpec(0, 127, \lin, 1, 0), {|ez|
	var knobVal = (ez.value).linlin(0,127,0,1);
	~triode.set(\tri, knobVal);
});
knobZ=EZKnob(w,60@90," GYRO_Z ",ControlSpec(0, 127, \lin, 1, 0), {|ez|
	var knobVal = (ez.value).linlin(0,127,0,1);
	~shaper.set(\lo, knobVal);
});

knobLpf=EZKnob(w,60@90," CUTOFF ",ControlSpec(0, 1, \lin, 0.01, 0.5), {|ez|
	~lpf.set(\cutoff, ez.value);
});

knobReso=EZKnob(w,60@90," RESON ",ControlSpec(0, 1, \lin, 0.01, 0.5), {|ez|
	~lpf.set(\resonance, ez.value);
});

knobX.setColors(Color.grey, Color.white);
knobY.setColors(Color.grey, Color.white);
knobZ.setColors(Color.grey, Color.white);
knobLpf.setColors(Color.grey, Color.white);

OSCdef(\coordChanged, {
	arg msg;
	// msg[1].postln;
	defer {
		knobX.value_(if(msg[1] == 0, 0, (msg[1])*2)).doAction;
		knobY.value_(if(msg[2].neg == 0, 0, (127-(msg[2].neg))*2)).doAction;
		knobZ.value_(if(msg[3].neg == 0, 0, (127-(msg[3].neg))*2)).doAction;
	};

	// randomly kick!
	if(msg[1] != 0 && ((msg[1] % 20)==0), {
		Synth(\drm, [
			\dur, 1 / Pwrand([5, 10], [3, 8].normalizeSum, 1).asStream.value,
			\tun, Pdup(Pexprand(1, 8), Pexprand(0.0001, 0.25)).asStream.value,
			\fed, Pexprand(0.00001, 2000.0).asStream.value,
			\amp, Pdup(Pexprand(1, 5), Pexprand(0.75, 2.0)).asStream.value,
			\rel, Pexprand(Pkey(\dur) / (4/3), Pkey(\dur) * 64).asStream.value,
			\pan, Pdup(Pexprand(1, 7), Pseq([0.5, 0.75, 1.0, 0.75, 0.5, 0.25, 0.0, 0.25], 1)).asStream.value,
			\legato, Pwrand([Pkey(\dur) * 1.5, Pkey(\dur) * 16], [1, 2].normalizeSum, 1).asStream.value,
			\sustain, Pdup(Pexprand(1, 3), Pexprand(0.1, 2.0)).asStream.value,
			\out, ~srcMixerChannel.asBus
		] ,target: ~srcMixerChannel.asTarget);
	});
}, '/gyro_read');
);

(21 % 10)

(127-60*2)
