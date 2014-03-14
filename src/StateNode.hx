package ;
import haxe.ds.Vector.Vector;
import hxparse.State;

using Lambda;
using StringTools;

class Step {
	public var state:State;
	public var position:Int;
	public var input:Int;
	public var transition:Edge;
	public function new() { }
	public function toString():String {
		return
			('$position: ').rpad(" ", 6) +
			(input == -1 ? "[enter]" : StateNode.printCode(input)).rpad(" ", 3) +
			(transition == null ? "" : " "+transition) +
			" " + (state == null ? "[exit]" : state.final > -1 ? "[final state]" : "")
		;
	}
}

class Edge {
	public var source:StateNode;
	public var drain:StateNode;
	public var inputs:Array<Int>;
	public var label:String;
	public function new() { }
	public function toString():String {
		return '$label';
	}
}

class StateNode {
	
	static public function processGraphState(state:State, nodeMap:Map<State, StateNode> = null):StateNode {
		
		if (state == null) return null;
		
		var node = nodeMap[state];
		if (node != null) return node;
		
		node = new StateNode();
		node.state = state;
		nodeMap[state] = node;
		
		var targets = new Map();
		for (i in 0...256) {
			var target = state.trans[i];
			if (target == null) continue;
			var inputs = targets[target];
			if (inputs == null) {
				targets[target] = [i];
			} else {
				inputs.push(i);
			}
		}
		
		node.targets = [];
		node.edgeByInput = new Vector<Edge>(256);
		
		for (target in targets.keys()) {
			var e:Edge = new Edge();
			e.inputs = targets[target];
			for (input in e.inputs) node.edgeByInput[input] = e;
			e.label = getRangeString(e.inputs);
			e.source = node;
			e.drain = processGraphState(target, nodeMap);
			node.targets.push(e);
		}
		
		return node;
	}
	
	static function getRangeString(inputs:Array<Int>) {
		if (inputs.length > 240) {
			return "[^" + getRangeString(complementOf(inputs)) + "]";
		} else if (inputs.length == 1) {
			return printCode(inputs[0]);
		}
		
		var ranges = [];
		var i = 0;
		var last = -1;
		var start = -1;
		
		function addRange() {
			if (start == last) {
				ranges.push(printCode(start));
			} else {
				ranges.push(printCode(start) + "-" +printCode(last));
			}
		}
		
		while (i < inputs.length) {
			var cur = inputs[i];
			if (start == -1) {
				start = cur;
				++i;
			} else if (cur != last + 1) {
				addRange();
				start = -1;
			} else {
				++i;
			}
			last = cur;
		}
		
		if (start != -1) {
			addRange();
		}
		
		return ranges.join(" ");
	}
	
	static public function printCode(i:Int) {
		if (i >= 32 && i <= 0x7F) {
			return switch (i) {
				case '"'.code: '\\"';
				case '\\'.code: '\\\\';
				case ' '.code: "' '";
				default: String.fromCharCode(i);
			}
		} else {
			return switch (i) {
				case "\n".code: "\\n";
				case "\r".code: "\\r";
				case "\t".code: "\\t";
				default: "\\\\" +i;
			}
		}
	}
	
	static function complementOf(inputs:Array<Int>) {
		var ret = [];
		for (i in 0...256) {
			if (!inputs.has(i)) {
				ret.push(i);
			}
		}
		return ret;
	}
	
	public var state:State;
	
	public var targets:Array<Edge>;
	public var edgeByInput:Vector<Edge>;
	
	public function new() { }
	
}