package generation;

import StateNode;

class Generator {
	
	var initial:StateNode;
	var current:StateNode;
	
	public var lastEdge:Edge;
	
	public function new(initial:StateNode) {
		this.initial = initial;
		reset();
	}
	
	public function reset() {
		current = initial;
	}
	
	public function next():Int {
		if (current.state.final > 0 || (lastEdge != null && current == lastEdge.drain && Math.random() < 0.1)) {
			reset();
		}
		var n = current.targets[Std.random(current.targets.length)];
		lastEdge = n;
		current = n.drain;
		return n.inputs[Std.random(n.inputs.length)];
	}
	
}