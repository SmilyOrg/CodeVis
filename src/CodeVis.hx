package ;

import byte.ByteData;
import com.furusystems.slf4hx.loggers.Logger;
import com.furusystems.slf4hx.Logging;
import cppparser.CppLexer;
import edit.Editor;
import flash.display.BitmapData;
import flash.display.PNGEncoderOptions;
import flash.display.Shape;
import flash.display.Sprite;
import flash.display.StageAlign;
import flash.display.StageQuality;
import flash.display.StageScaleMode;
import flash.events.Event;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
import flash.events.TimerEvent;
import flash.events.UncaughtErrorEvent;
import flash.external.ExternalInterface;
import flash.geom.Matrix;
import flash.geom.Transform;
import flash.Lib;
import flash.net.FileReference;
import flash.ui.Keyboard;
import flash.utils.ByteArray;
import flash.utils.Timer;
import flashx.textLayout.edit.SelectionState;
import flashx.textLayout.events.SelectionEvent;
import haxe.Http;
import haxeparser.Data.Token;
import haxeparser.Data.TokenDef;
import haxeparser.HaxeLexer;
import haxeparser.HaxeParser;
import hxparse.Lexer;
import hxparse.Ruleset.Ruleset;
import hxparse.State;
import hxparse.UnexpectedChar;

using StringTools;

typedef LexerOption = {
	type:Class<Lexer>,
	ruleset:Dynamic
}

class CodeVis extends Sprite {
	
	static function main() {
		var stage = Lib.current.stage;
		stage.scaleMode = StageScaleMode.NO_SCALE;
		stage.align = StageAlign.TOP_LEFT;
		
		stage.addChild(new CodeVis());
	}
	
	private static var L:Logger = Logging.getLogger(CodeVis);
	
	var defaultPath = "test/Main.hx";
	var consoleHeight:Float = 100;
	var externalSize = true;
	//var externalSize = false;
	
	var filePath:String;
	
	var console:Console;
	var editor:Editor;
	var selectionState:SelectionState;
	
	var visContainer:Sprite;
	var nodeVis:NodeVis;
	
	var progressBar:Shape;
	var progressBarProgress:Float = 0;
	
	var lexers:Array<LexerOption> = [
		{ type: HaxeLexer, ruleset: HaxeLexer.tok },
		{ type: PrintfParser.PrintfLexer, ruleset: PrintfParser.PrintfLexer.tok },
		{ type: JSONParser.JSONLexer, ruleset: JSONParser.JSONLexer.tok },
		{ type: templo.Lexer, ruleset: templo.Lexer.element },
		{ type: CppLexer, ruleset: CppLexer.tok }
	];
	
	var currentLexer:LexerOption;
	
	var source:String;
	var sourceName:String;
	var lexer:Lexer;
	var parser:HaxeParser;
	var tokenizationStart:Int;
	var current:Token;
	var totalTokens:Int;
	
	var roots:Array<StateNode>;
	var nodeMap:Map<State, StateNode>;
	var steps:Array<StateNode.Step>;
	var posMap:Map<Int, Array<StateNode.Step>>;
	
	var delayedUpdate:Timer;
	
	//var consoleVisible:Bool = false;
	//var consoleBar:Sprite;
	
	function new() {
		super();
		
		// TODO token plugins
		
		currentLexer = lexers[0];
		//currentLexer = lexers[1];
		//currentLexer = lexers[2];
		//currentLexer = lexers[3];
		//currentLexer = lexers[4];
		
		
		console = new Console();
		addChild(console);
		
		Logging.logBinding = console;
		
		progressBar = new Shape();
		progressBar.y = consoleHeight;
		addChild(progressBar);
		
		editor = new Editor();
		editor.y = consoleHeight+1;
		editor.addEventListener(Event.CHANGE, editorChange);
		editor.addEventListener(SelectionEvent.SELECTION_CHANGE, selectionChange);
		addChild(editor);
		
		visContainer = new Sprite();
		nodeVis = new NodeVis();
		visContainer.y = 20;
		visContainer.addChild(nodeVis);
		addChild(visContainer);
		
		//consoleBar = new Sprite();
		//consoleBar.buttonMode = true;
		//consoleBar.addEventListener(MouseEvent.MOUSE_DOWN, toggleConsole);
		//addChild(consoleBar);
		
		//toggleConsole();
		//redrawConsoleBar();
		
		#if !expose_lexer_state
			#error "Using this class requires -D expose_lexer_state"
		#end
		
		delayedUpdate = new Timer(400, 1);
		delayedUpdate.addEventListener(TimerEvent.TIMER, update);

		
		//L.debug("debug");
		//L.info("info");
		//L.warn("warn");
		//L.error("error");
		//L.fatal("fatal");
		
		addEventListener(Event.ADDED_TO_STAGE, addedToStage);
		
		if (ExternalInterface.available) {
			defaultPath = "bin/" + defaultPath;
			ExternalInterface.addCallback("locationHashChanged", locationHashChanged);
			ExternalInterface.call("swfInit");
		}
		
		filePath = defaultPath;
		loadPath();
	}
	
	function addedToStage(e:Event) {
		loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, uncaughtError);
		
		nodeMap = new Map<State, StateNode>();
		
		roots = new Array<StateNode>();
		for (ruleset in (Reflect.getProperty(currentLexer.type, "generatedRulesets"):Array<hxparse.Ruleset<Dynamic>>)) {
			roots.push(StateNode.processGraphState(ruleset.state, nodeMap));
		}
		
		visualizeNodes();
		
		var file = loaderInfo.parameters.file;
		if (file != null) {
			L.info("Loading file", file);
		}
		
		stage.addEventListener(Event.RESIZE, stageResize);
		stage.addEventListener(MouseEvent.MOUSE_WHEEL, mouseWheel);
		stage.addEventListener(MouseEvent.MOUSE_WHEEL, mouseWheel, true);
		stage.addEventListener(MouseEvent.MIDDLE_MOUSE_DOWN, mouseDown);
		stage.addEventListener(MouseEvent.MIDDLE_MOUSE_UP, mouseUp);
		stage.addEventListener(KeyboardEvent.KEY_DOWN, keyDown);
		stageResize();
	}
	
	function uncaughtError(e:UncaughtErrorEvent) {
		L.error("Uncaught error", e.error);
	}
	
	//function toggleConsole(e:MouseEvent = null) {
		//consoleVisible = !consoleVisible;
		//consoleVisible ? GameConsole.showConsole() : GameConsole.hideConsole();
	//}
	
	//function redrawConsoleBar() {
		//if (stage == null) return;
		//var g:Graphics = consoleBar.graphics;
		//g.clear();
		//g.beginFill(0x000000, 0.8);
		//g.drawRect(0, 0, stage.stageWidth, editor.y);
	//}
	
	function locationHashChanged(hash:String) {
		if (hash == "") {
			filePath = defaultPath;
			loadPath();
		}
		
		if (hash.charAt(0) != "#") return;
		
		hash = hash.substr(1);
		
		if (hash.charAt(0) == "/") {
			filePath = hash.substr(1);
			if (filePath == "") filePath = defaultPath;
			loadPath();
		}
	}
	
	function loadPath() {
		L.info("Loading", filePath);
		var http = new Http(filePath);
		http.onData = fileLoaded;
		http.onError = loadError;
		http.request();
	}
	
	function loadError(msg:String) {
		L.error(msg);
	}
	
	function editorChange(e:Event) {
		//updateLexer(editor.text, "<editor>");
		//tokenizeStart();
		//resizeToContent();
		tokenizeStop();
		delayedUpdate.reset();
		delayedUpdate.start();
	}
	
	function updateSource(source:String, sourceName:String) {
		this.source = source;
		this.sourceName = sourceName;
		updateLexer(source, sourceName);
		parser = new HaxeParser(ByteData.ofString(source), sourceName);
		tokenizeStart();
	}
	
	function updateLexer(source:String, fileName:String) {
		if (lexer != null) {
			lexer.stateCallback = null;
		}
		//lexer = new HaxeLexer(ByteData.ofString(source), fileName);
		lexer = Type.createInstance(currentLexer.type, [ByteData.ofString(source), fileName]);
		lexer.stateCallback = stateCallback;
	}
	
	function stateCallback(state:State, position:Int, input:Int) {
		var node = StateNode.processGraphState(state, nodeMap);
		
		nodeVis.highlight(node);
		
		var step = new StateNode.Step();
		step.state = state;
		step.position = position;
		step.input = input;
		if (node != null && input > -1) step.transition = node.edgeByInput[input];
		
		steps.push(step);
		var ps = posMap[position];
		if (ps == null) posMap[position] = ps = new Array<StateNode.Step>();
		ps.push(step);
	}
	
	
	function fileLoaded(data:String) {
		data = data.replace("\r", "");
		
		editor.text = data;
		resizeToContent();
		
		updateSource(data, filePath);
	}
	
	
	function tokenizeStart() {
		tokenizeStop();
		//nodeVis.clear();
		nodeVis.clearHighlight();
		
		tokenizationStart = Lib.getTimer();
		totalTokens = 0;
		editor.clearTokens();
		//nodeMap = new Map<State, StateNode>();
		posMap = new Map < Int, Array<StateNode.Step> > ();
		
		addEventListener(Event.ENTER_FRAME, tokenizeRun);
		//nextToken();
		//nextToken();
		//nextToken();
		//nextToken();
	}
	
	function tokenizeRun(e:Event) {
		var start = Lib.getTimer();
		var end = false;
		while (Lib.getTimer()-start < 10) {
			//var before = Lib.getTimer();
			end = nextToken();
			//var after = Lib.getTimer();
			//L.info(after-before+"ms");
			totalTokens++;
			if (end) break;
		}
		if (end) tokenizeStop();
	}
	
	function nextToken():Bool {
		steps = [];
		try {
			current = lexer.token(currentLexer.ruleset);
		} catch(e:UnexpectedChar) {
			L.error(e);
			return true;
		} catch(e:LexerError) {
			L.error(e.msg);
			return true;
		}
		
		updateProgress();
		
		var end = current == null || current.tok == TokenDef.Eof;
		if (end) return true;
		
		editor.addToken(current, steps);
		
		return false;
	}
	
	function updateProgress() {
		progressBarProgress = current == null ? 1 : current.pos.max/source.length;
		updateProgressBar();
	}
	
	function updateProgressBar() {
		var g = progressBar.graphics;
		g.clear();
		g.lineStyle(1, 0xFDDBAC, 0.3);
		g.moveTo(0, 0);
		g.lineTo(progressBarProgress*stage.stageWidth, 0);
	}
	
	function tokenizeStop() {
		if (!hasEventListener(Event.ENTER_FRAME)) return;
		L.info('Lexed $totalTokens tokens in ${Lib.getTimer()-tokenizationStart}ms');
		removeEventListener(Event.ENTER_FRAME, tokenizeRun);
		editor.updateFlow();
		selectionChange();
		
		parseSource();
		
		//screenshot();
		//visualizeNodes();
		//delayedUpdate.reset();
		//delayedUpdate.start();
	}
	
	function parseSource() {
		var ast = parser.parse();
		for (decl in ast.decls) {
			L.debug(decl);
		}
	}
	
	function screenshot() {
		var bounds = nodeVis.getBounds(nodeVis);
		
		var margin = 20;
		
		var cw = bounds.width, ch = bounds.height;
		//var tw = 800, th = Math.ceil(tw/cw*ch);
		
		//var data = new BitmapData(800, 600, false, stage.color);
		//var data = new BitmapData(1920, 1080, false, stage.color);
		var data = new BitmapData(1920*2, 1080*2, false, stage.color);
		
		var tw = data.width-margin*2, th = data.height-margin*2;
		var scale = tw/th < cw/ch ? tw/cw : th/ch;
		
		var m = new Matrix();
		m.translate(-bounds.left, -bounds.top);
		m.scale(scale, scale);
		m.translate(tw-cw*scale+margin, margin);
		
		data.drawWithQuality(nodeVis, m, null, null, null, true, StageQuality.HIGH_16X16);
		
		//addChild(new Bitmap(data));
		
		var bytes = new ByteArray();
		data.encode(data.rect, new PNGEncoderOptions(), bytes);
		var f = new FileReference();
		f.save(bytes, "graph.png");
	}
	
	function selectionChange(e:SelectionEvent = null) {
		nodeVis.clearSelection();
		editor.hideTooltip();
		
		var s = e == null ? selectionState : e.selectionState;
		if (s == null) return;
		
		selectionState = s;
		//var pos = s.anchorPosition;
		var acc = new Array<StateNode.Step>();
		var limit = 50;
		var start = s.absoluteStart;
		var end = s.absoluteEnd;
		var diff = end-start;
		//if (diff <= 0) return;
		//if (diff <= 0) end += 1;
		if (diff <= 0) start -= 1;
		var trim = diff > limit;
		end = trim ? start+limit : end;
		for (pos in start...end) {
			var ps = posMap[pos];
			if (ps != null) acc = acc.concat(ps);
		}
		for (node in acc) {
			nodeVis.select(nodeMap[node.state]);
		}
		editor.showTooltip(s.activePosition, acc.join("\n") + (trim ? "\n..." : ""));
	}
	
	function visualizeNodes() {
		
		var keys = nodeMap.keys();
		if (!keys.hasNext()) return;
		var node = nodeMap[keys.next()];
		
		//var root = node;
		//while (root.parent != null) root = root.parent;
		
		//L.debug("root", root.targets.join("\n"));
		
		nodeVis.x = nodeVis.y = 0;
		nodeVis.scaleX = nodeVis.scaleY = 1;
		
		nodeVis.clear();
		for (i in 0...roots.length) {
			var root = roots[i];
			nodeVis.visualize(root, (Reflect.getProperty(currentLexer.type, "generatedRulesetNames"):Array<String>)[i]);
		}
		
		updateNodeVis();
		
		//screenshot();
	}
	
	function update(e:Event) {
		resizeToContent();
		updateSource(editor.text, "<editor>");
	}
	
	function updateNodeVis() {
		var bounds = nodeVis.getBounds(nodeVis);
		visContainer.x = stage.stageWidth-bounds.right;
	}
	
	function keyDown(e:KeyboardEvent) {
		if (e.ctrlKey && e.keyCode == Keyboard.N) screenshot();
	}
	
	function mouseWheel(e:MouseEvent) {
		if (!e.ctrlKey) return;
		e.stopPropagation();
		e.stopImmediatePropagation();
		
		
		//var scale = nodeVis.scaleX*(1+e.delta*0.1);
		var sign = e.delta > 0 ? 1 : -1;
		var scale = 1+sign*0.2;
		
		//var scale = nodeVis.scaleX*(1-e.delta*0.2);
		
		var mx = visContainer.mouseX, my = visContainer.mouseY;
		
		var m = nodeVis.transform.matrix;
		
		var pm = m.clone();
		var t = pm.clone();
		
		m.translate(-mx, -my);
		m.scale(scale, scale);
		m.translate(mx, my);
		
		nodeVis.transform.matrix = m;
		
		//Juicer.to(nodeVis.transform.matrix, m);
		
		//m.tween(a
	}
	
	function mouseDown(e:MouseEvent) {
		nodeVis.startDrag();
	}
	
	function mouseUp(e:MouseEvent) {
		nodeVis.stopDrag();
	}
	
	function tweenMatrix(target:Transform, pm:Matrix, t:Matrix, m:Matrix, v:Float) {
		if (target == null) return;
		t.a = pm.a+(pm.a-m.a)*v;
		t.b = pm.b+(pm.b-m.b)*v;
		t.c = pm.c+(pm.c-m.c)*v;
		t.d = pm.d+(pm.d-m.d)*v;
		t.tx = pm.tx+(pm.tx-m.tx)*v;
		t.ty = pm.ty+(pm.ty-m.ty)*v;
		target.matrix = t;
	}
	
	function resizeToContent() {
		if (externalSize && ExternalInterface.available) ExternalInterface.call("resizeSWF", -1, height);
	}
	
	function stageResize(e:Event = null) {
		//redrawConsoleBar();
		if (!externalSize || !ExternalInterface.available) {
			editor.resize(stage.stageWidth, stage.stageHeight-consoleHeight);
		}
		console.resize(stage.stageWidth, consoleHeight);
		updateProgressBar();
		updateNodeVis();
	}
	
}