package ;
import edit.Tag;
import hxparse.Lexer;
import hxparse.State;

class StepTag extends Tag {
	var steps:Array<StateNode.Step>;
	public function new(steps, min, max) {
		super(min, max);
		this.steps = steps;
	}
	override function getInfo() {
		return super.getInfo() + steps.join("\n")+"\n";
	}
}

class StepHandler {
	public var posMap:Map<Int, Array<StateNode.Step>>;
	var steps:Array<StateNode.Step>;
	var nodeMap:Map<State, StateNode>;
	public function new(nodeMap) {
		this.nodeMap = nodeMap;
	}
	public function init(lexer:Lexer) {
		posMap = new Map<Int, Array<StateNode.Step>>();
		lexer.stateCallback = stateCallback;
	}
	public function pretoken() {
		steps = [];
	}
	public function posttoken() {
		return steps;
	}
	function stateCallback(state:State, position:Int, input:Int) {
		var step = new StateNode.Step();
		step.state = state;
		step.position = position;
		step.input = input;
		steps.push(step);
		
		var ps = posMap[position];
		if (ps == null) posMap[position] = ps = new Array<StateNode.Step>();
		ps.push(step);
		
		var node = StateNode.processGraphState(step.state, nodeMap);
		if (node != null && input > -1) step.transition = node.edgeByInput[input];
		
		stepCallback(step, node);
	}
	dynamic public function stepCallback(step:StateNode.Step, node:StateNode) {}
}