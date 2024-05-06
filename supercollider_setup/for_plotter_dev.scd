(
// s.options.outDevice ="BlackHole 16ch"; // in case using Reaper
s.options.outDevice ="MacBook Pro Speakers";
s.options.numInputBusChannels = 0;
s.options.numOutputBusChannels = 16;
s.waitForBoot {
	~sampler_engine = MyLivePerformanceTool("/Users/karnpaponboonput/Desktop/samples/soundpharm/FoleyPerc - Loops/");
}
)

~sampler_engine.analyze;
~sampler_engine.map_dataset;

(
~sampler_engine.normalize;
~sampler_engine.map_kd_tree(0.01);
)

~sampler_engine.loadPreProcessedData("/Users/karnpaponboonput/Desktop/test-pref-data");

~sampler_engine.external_mixer_(~srcMixerChannel);
~sampler_engine.outbus_(2);

// inject GUI and then start engine.
(
var kNearest, kNearestDist;
var buttonValue="OSC";

w = Window("test",Rect(0,0,600,480+(20*2) ), resizable: false, border: false).front;
w.view.decorator = FlowLayout(w.view.bounds);
~sampler_engine.controller(parent: w);

t = ToggleButton(w,buttonValue,{
	arg button,bool;
	~sampler_engine.toggleOSC(true);
},{
	arg button,bool;
	~sampler_engine.toggleOSC(false);
},false,100,20, Color.green, Color.white);

StaticText(w,Rect(0,0,70,20)).string_("neighbours:");
kNearest = TextView(w, Rect(0,0,70,20)).string_("").editable_(false);
StaticText(w,Rect(0,0,70,20)).string_("distances:");
kNearestDist = TextView(w, w.view.decorator.indentedRemaining.width@20).string_("").editable_(false);
~sampler_engine.listen(parent: w, kNearest: kNearest, kNearestDist: kNearestDist);
)