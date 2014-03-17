package ;
import haxe.Timer;

class Stopwatch {
	
	static var times:Map<String, Float> = new Map<String, Float>();
	
	static public function tick(label:String = "default") {
		times[label] = Timer.stamp();
	}
	
	static public function tock(label:String = "default"):Float {
		return (Timer.stamp()-times[label])*1000;
	}
	
}