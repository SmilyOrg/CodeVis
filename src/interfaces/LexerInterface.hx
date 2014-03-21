package interfaces;
import edit.Tag;
import hxparse.Ruleset.Ruleset;
import hxparse.State;

interface LexerInterface {
	//function build(roots:Array<RootNode>, nodeMap:Map<State, StateNode>);
	function getRulesets():Array<Ruleset<Dynamic>>;
	function update(source:String, sourceName:String):Void;
	function nextTag():Tag;
}
