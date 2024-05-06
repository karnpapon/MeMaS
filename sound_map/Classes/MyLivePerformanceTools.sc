// =========================================================
// Title         : MyLivePerformanceTool
// Description   : personal live performance tool.
// Version       : 1.0
// =========================================================


MyLivePerformanceTool {
	classvar <>server;
	var <>external_mixer, <>outbus;
	var src, analyses, indices, umapped, normed, tree, point, controllers;
	var previous, play_slice, point, pen_tool_osc, previous, colorTask, synthDef;

	*new {
		arg folder_path;
		server = server ? Server.default;
		^super.new.init(folder_path);
	}

	init {
		arg folder_path;

		fork {
			// load into a buffer
			var loader = FluidLoadFolder(folder_path).play(server,{"done loading folder".postln;});
			server.sync;
			"::::synced:::".postln;
			if(loader.buffer.numChannels > 1) {
				src = Buffer(server);
				loader.buffer.numChannels.do{
					arg chan_i;
					FluidBufCompose.processBlocking(server,
						loader.buffer,
						startChan:chan_i,
						numChans:1,
						gain:loader.buffer.numChannels.reciprocal,
						destination:src,
						destGain:1,
						action:{"copied channel: %".format(chan_i).postln}
					);
				};
			} {
				"loader buffer is already mono".postln;
				src = loader.buffer;
			};

			"init::done".postln;
			"start slicing...please wait".postln;
			this.processing();
		}
	}

	processing {
		this.slice();
	}

	get_indices {
		^indices;
	}

	get_src {
		^src;
	}

	slice {
		arg threshold = 1, metric = 9;
		// lower threshold for shorter sound.

		indices = Buffer(server);
		FluidBufOnsetSlice.processBlocking(
			server,
			src,
			metric:metric, // RComplexDev.
			threshold:threshold, // how to determine onset point.
			indices:indices,
			action:{
				"found % slice points".format(indices.numFrames).postln;
				"average duration per slice: %".format(src.duration / (indices.numFrames+1)).postln;
				"slice::done".postln;
		});
	}

	analyze {
		arg numCoeffs = 13, startCoeff = 1;
		// var trainingLabels = FluidLabelSet(server);
		// var labels = ["synth","bells"];
		// var counter=0;

		analyses = FluidDataSet(server);
		indices.loadToFloatArray(action:{
			arg fa;
			var mfccs = Buffer(server);
			var stats = Buffer(server);
			var flat = Buffer(server);

			fa.doAdjacentPairs{
				arg start, end, i;
				var num = end - start;
				var id = "mfcc-analysis-%".format(i);

				// MFCC will analyze by using timbre information.
				// notice `startCoeff` start from 1, since 0 = average volume (we wanted only timbre factors).
				// readmore: https://learn.flucoma.org/reference/mfcc/#mfcc-0
				FluidBufMFCC.processBlocking(server,src,start,num,features:mfccs,numCoeffs:numCoeffs,startCoeff:startCoeff);
				FluidBufStats.processBlocking(server,mfccs,stats:stats,select:[\mean]);

				// flatten 13 layers into 13 frames (after select: [\mean]).
				// in others words, turn vertical array ([x][x][x][x]) to horizontal ([x,x,x,x]).
				FluidBufFlatten.processBlocking(server,stats,destination:flat);

				analyses.addPoint(i,flat);

				"analyzing slice % / %".format(i+1,fa.size-1).postln;

				// otherwise, it'll throw an error when many tasks are pushed to stack.
				if((i%100) == 99){
					server.sync;
					"::::synced:::".postln;
				}
			};

			server.sync;
			"::::synced:::".postln;

			analyses.print;
			"analyze::done".postln;

			/*mfccs.numFrames.do{
			arg frame, i;
			var id = "mfcc-analysis-%".format(counter.asInteger);
			// FluidBufFlatten.processBlocking(server,mfccs,frame,1, destination: flat);
			// ~ds.addPoint(id,flat);
			// i.postln;
			trainingLabels.addLabel(id,labels[i]);
			counter = counter + 1;
			};

			"trainingLabels::done".postln;
			trainingLabels.print;*/
		});
	}

	map_dataset {
		arg numNeighbours=15, minDist=0.5;
		// minDist determines how close similar sample should be (large number less proximity)

		"start map_dataset...please wait".postln;
		umapped = FluidDataSet(server);
		// FluidUMAP turn 13 dimensional spaces into 2 dimensional spaces (for plotting in GUI later).
		FluidUMAP(server,numNeighbours:numNeighbours,minDist:minDist).fitTransform(
			analyses,
			umapped,
			action:{"map_dataset:::done".postln}
		);
	}

	normalize {
		normed = FluidDataSet(server);
		FluidNormalize(server).fitTransform(umapped,normed);
		"normalized::done".postln;
	}

	map_kd_tree {
		arg radius = 0.01, numNeighbours=1;
		tree = FluidKDTree(server,numNeighbours: numNeighbours, radius: radius).fit(normed);
	}

	play_slice {
		arg index;
		{
			var startsamp = Index.kr(indices,index);
			var stopsamp = Index.kr(indices,index+1);
			var phs = Phasor.ar(0,BufRateScale.ir(src),startsamp,stopsamp);
			var sig = BufRd.ar(1,src,phs);
			var dursecs = (stopsamp - startsamp) / BufSampleRate.ir(src);
			var env;

			dursecs = min(dursecs,1);

			env = EnvGen.kr(Env([0,1,1,0],[0.03,dursecs-0.06,0.03]),doneAction:2);
			sig = sig.dup * env;
			// ReplaceOut.ar(outbus ?? 0, sig);
		}.play(target:external_mixer.asTarget ?? nil, outbus: external_mixer.asBus ?? nil) // play in target group otherwise play to default group.
	}


	plot {
		arg window=Rect(0,0,822,457.5);
		normed.dump({
			arg dict;
			point = Buffer.alloc(server,2);
			previous = nil;
			dict.postln;
			defer{
				MyPlotter(bounds: window, dict:dict, mouseMoveAction:{
					arg view, x, y;
					point.setn(0,[x,y]);
					tree.kNearest(point,1,{
						arg nearest;
						if (
							(nearest.isKindOf(Array) && (nearest.size > 0)) ||
							nearest.isKindOf(Symbol) &&
							(nearest != previous)
						) {
							view.highlight_(nearest);
							this.play_slice(nearest.asInteger);
							previous = nearest;
						};
					});
				});
			}
		});
		"plot::done".postln;
	}

	controller {
		arg parent, bound;
		var w, sliders;
		var node;
		var params, specs;
		var args;

		params = ["numNeighbours", "radius"];
		specs = [
			ControlSpec(1, 12, \lin, 1, 1, \numNeighbours),
			ControlSpec(0.01, 1, \lin,0.01,0.01,\radius),
		];

		// make the window for separated window
		/*w = Window("another control panel", bound);
		w.front;
		w.view.decorator = FlowLayout(w.view.bounds);
		w.view.decorator.gap=2@2;*/

		sliders = params.collect { |param, i|
			EZSlider(parent, bound ?? 592@20, param, specs[i], labelWidth: 110)
			.setColors(Color.grey,Color.white, Color.grey(0.7),Color.grey, Color.white, Color.yellow);
		};

		sliders.do { |slider|
			slider.action = { |sl|
				this.map_kd_tree(radius: sliders[1].value, numNeighbours: sliders[0].value );
			}
		}
	}

	listen {
		arg address, osc_def_name, parent, bound, kNearest, kNearestDist;
		var k = 2;
		var internal_bound = bound ?? Rect(0,0,592,460);
		normed.dump({
			arg dict;
			point = Buffer.alloc(server,2);
			previous = nil;

			defer {
				MyPlotter(
					parent: parent,
					bounds: internal_bound,
					dict:dict,
					onViewInit: { |view|
						var penLineWidth=6, nearestLineWidth=4;
						var near_x, near_y;

						view.asParent.onClose = { this.stopListen() };
						view.asPenToolNearest_([0.5*internal_bound.width,0.5*internal_bound.height]);
						view.asPenToolOsc_([0.5*internal_bound.width,0.5*internal_bound.height]);

						OSCdef(osc_def_name ?? \test_plotter_trigger, {|msg, time, addr, recvPort|
							var x = msg[1]; // normalized value (0..1) purposely for kNearest checking.
							var y = msg[2]; // normalized value (0..1)
							var canvas_x = x*internal_bound.width;
							var canvas_y = y*internal_bound.height;

							point.setn(0, [x,1 - y]);

							// QT GUI code must be schedule on the lower priority AppClock (defer)
							// https://youtu.be/mAA9Hcw1pg4?t=2410
							{
								// scale to fit window bound (for drawing line).
								view.asView.drawFunc_({
									arg viewport;

									var x1 = view.asPenToolOsc.asPoint.x;
									var y1 = view.asPenToolOsc.asPoint.y;
									var x2 = view.asPenToolNearest.asPoint.x;
									var y2 = view.asPenToolNearest.asPoint.y;

									view.drawGradientLine(
										x1@y1,
										x2@y2,
										"asPenToolOsc_",
										"asPenToolNearest_",
										nearestLineWidth,canvas_x,canvas_y, viewport
									);
									view.drawDataPoints(viewport);
									view.drawHighlight(viewport);
								});
								view.refresh;
							}.defer;

							tree.kNearest(point,tree.numNeighbours,{
								arg nearest;

								var x1 = view.asPenToolOsc.asPoint.x;
								var y1 = view.asPenToolOsc.asPoint.y;
								var x2 = view.asPenToolNearest.asPoint.x;
								var y2 = view.asPenToolNearest.asPoint.y;

								if (nearest.isKindOf(Symbol)) { nearest = [nearest] };
								if ((nearest.size > 0) && (nearest != previous)) {
									nearest.do { |near_point|
										if (dict.at("data").at(near_point.asString).notNil) {
											near_x = dict.at("data").at(near_point.asString)[0];
											near_y = dict.at("data").at(near_point.asString)[1];

											{
												var target_near_x = near_x*internal_bound.width;
												var target_near_y = (1 - near_y)*internal_bound.height;
												view.asView.drawFunc_({
													arg viewport;

													var x1 = view.asPenToolOsc.asPoint.x;
													var y1 = view.asPenToolOsc.asPoint.y;
													var x2 = target_near_x;
													var y2 = target_near_y;

													var vw = viewport.bounds.width;
													var vh = viewport.bounds.height;
													var vp = view.getPoint(near_point);

													var	x2_dyn = vp.x.linlin(view.zoomxmin,view.zoomxmax,0,vw,nil) - (view.pointSize/2);
													var y2_dyn = vp.y.linlin(view.zoomymax,view.zoomymin,0,vh,nil) - (view.pointSize/2);

													view.drawGradientLine(x1@y1,x2_dyn@y2_dyn,"asPenToolOsc_","asPenToolNearest_",nearestLineWidth,x1,y1, viewport);
													view.drawDataPoints(viewport);
													view.drawHighlight(viewport);
												});

												view.highlight_(near_point);
												// intentionally, not going to play slice simultanoesly since it's amplitude will be summed up.
												// instead play them in a row.
												// the result is the more neighbor the "stutter" sound becomes.
												this.play_slice(near_point.asInteger);
												view.refresh;
											}.defer;
										};
									};
									previous = nearest;
								};

							});
						}, address ?? '/test_plotter/1');

						this.toggleOSC(false);
					},

					mouseMoveAction:{
						arg view, x,y;
						var penLineWidth=6, nearestLineWidth=4;
						var near_x, near_y;

						point.setn(0,[x,y]);

						tree.kNearest(point,tree.numNeighbours, {
							arg nearest;

							var x1 = view.asPenToolMouse.asPoint.x;
							var y1 = view.asPenToolMouse.asPoint.y;
							var x2 = view.asPenToolNearest.asPoint.x;
							var y2 = view.asPenToolNearest.asPoint.y;

							if (nearest.isKindOf(Symbol)) { nearest = [nearest] };
							// found nearest neighbor (mouse).
							if ((nearest.size > 0) && (nearest != previous)) {

								nearest.do { |near_point|
									if (dict.at("data").at(near_point.asString).notNil) {
										near_x = dict.at("data").at(near_point.asString)[0];
										near_y = dict.at("data").at(near_point.asString)[1];

										{
											var target_near_x = near_x*internal_bound.width;
											var target_near_y = (1 - near_y)*internal_bound.height;
											view.asView.drawFunc_({
												arg viewport;

												var x1 = view.asPenToolMouse.asPoint.x;
												var y1 = view.asPenToolMouse.asPoint.y;
												var x2 = target_near_x;
												var y2 = target_near_y;

												var vw = viewport.bounds.width;
												var vh = viewport.bounds.height;
												var vp = view.getPoint(near_point);

												var	x2_dyn = vp.x.linlin(view.zoomxmin,view.zoomxmax,0,vw,nil) - (view.pointSize/2);
												var y2_dyn = vp.y.linlin(view.zoomymax,view.zoomymin,0,vh,nil) - (view.pointSize/2);

												// to show data in gui, currently not support zoom yet
												kNearest.string = near_point;
												kNearestDist.string = (X: target_near_x, Y: target_near_y).asString;

												view.drawGradientLine(
													x1@y1,x2_dyn@y2_dyn,"asPenToolMouse_","asPenToolNearest_",nearestLineWidth, viewport);
												view.drawDataPoints(viewport);
												view.drawHighlight(viewport);
											});

											view.highlight_(near_point);
											// intentionally, not going to play slice simultanoesly since it's amplitude will be summed up.
											// instead play them in a row.
											// the result is the more neighbor the "stutter" sound becomes.
											this.play_slice(near_point.asInteger);
											view.refresh;
										}.defer;
									};
								};
								previous = nearest;
							};
						});
					}
				);
			}
		});

		"listen osc on address %".format(address ?? '/test_plotter/1').postln;
	}

	toggleOSC{
		arg osc_enabled;

		if(osc_enabled, {
			"osc_enabled".postln;
			OSCdef(\test_plotter_trigger).enable;
		},{
			"osc_disabled".postln;
			OSCdef(\test_plotter_trigger).disable;
		})
		;
	}

	stopListen {
		arg osc_def_name;
		"stop listening osc: %, port: %, address: %".format(osc_def_name, 57120, '/test_plotter/1').postln;
		OSCdef(osc_def_name ?? \test_plotter_trigger).clear;
	}

	exportProcessedData {
		arg dir,path;
		this.exportAnalyzedData(dir,path);
		this.exportUMAPData(dir,path);
		this.exportNormalizedData(dir,path);
		this.exportKdTreeData(dir,path);
	}

	exportAnalyzedData {
		arg dir,path;
		var newPath = dir ++ path ++ "_analyzed-data" ++ ".json";
		analyses.write(newPath);
	}

	exportUMAPData {
		arg dir,path;
		var newPath = dir ++ path ++ "_umapped-data" ++ ".json";
		umapped.write(newPath);
	}

	exportNormalizedData {
		arg dir,path;
		var newPath = dir ++ path ++ "_normalized-data" ++ ".json";
		normed.write(newPath);
	}

	exportKdTreeData {
		arg dir,path;
		var newPath = dir ++ path ++ "_kdtree-data" ++ ".json";
		tree.write(newPath);
	}

	loadPreProcessedData {
		arg path;
		var p;

		p = PathName(path);
		p.files.do {|file|
			if ("_normalized-data.json".matchRegexp(file.fullPath)) {
				var radius = 0.01, numNeighbours=1;
				normed = FluidDataSet(server).read(file.fullPath);
				tree = FluidKDTree(server,numNeighbours: numNeighbours, radius: radius).fit(normed);
				// trainingLabels = FluidLabelSet(server);
			};

			"loadPreProcessedData::done".postln;
			/*if ("_kdtree-data.json".matchRegexp(file.fullPath)) {
			var radius = 0.01, numNeighbours=1;
			"map_kd_tree: %".format(this.map_kd_tree).postln;
			};*/
		};

		// trainingLabels.print;
	}

}
