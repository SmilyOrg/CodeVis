package ;

import com.furusystems.slf4hx.loggers.Logger;
import com.furusystems.slf4hx.Logging;
import edit.Editor;
import eu.liquify.ui.ListBox;
import eu.liquify.ui.ListItem;
import flash.display.BitmapData;
import flash.display.DisplayObject;
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
import hxparse.Ruleset.Ruleset;
import hxparse.State;
import hxparse.UnexpectedChar;
import interfaces.LexerInterface;

using StringTools;

typedef RootNode = {
	node:StateNode,
	ruleset:Ruleset<Dynamic>
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
	//var defaultPath = "test/listbase.h";
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
	
	/*
	var lexers:Array<LexerOption> = [
		{ type: HaxeLexer, ruleset: HaxeLexer.tok },
		{ type: PrintfParser.PrintfLexer, ruleset: PrintfParser.PrintfLexer.tok },
		{ type: JSONParser.JSONLexer, ruleset: JSONParser.JSONLexer.tok },
		{ type: templo.Lexer, ruleset: templo.Lexer.element },
		{ type: CppLexer, ruleset: CppLexer.tok }
	];
	
	var currentLexer:LexerOption;
	*/
	
	var stepHandler:StepHandler;
	var lexerfaces:Array<LexerInterface> = [];
	var lexerface:LexerInterface;
	
	var source:String = null;
	var sourceName:String;
	var tokenizationStart:Int;
	var totalTokens:Int;
	
	var roots:Array<RootNode>;
	var nodeMap:Map<State, StateNode>;
	
	var delayedUpdate:Timer;
	
	var dropdown:ListBox;
	
	//var consoleVisible:Bool = false;
	//var consoleBar:Sprite;
	
	function new() {
		super();
		
		roots = [];
		nodeMap = new Map<State, StateNode>();
		stepHandler = new StepHandler(nodeMap);
		
		lexerfaces.push(new interfaces.haxe.Interface.Lexerface(stepHandler));
		lexerfaces.push(new interfaces.cpp.Interface.Lexerface(stepHandler));
		//lexerfaces.push(new interfaces.MiscInterfaces.PrintfLexerface(stepHandler));
		//lexerfaces.push(new interfaces.MiscInterfaces.TemploLexerface(stepHandler));
		
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
		
		dropdown = new ListBox();
		dropdown.x = dropdown.gridWidth+5;
		dropdown.y = 5;
		dropdown.addChild(new ListItem("Haxe", lexerfaces[0]));
		dropdown.addChild(new ListItem("C++", lexerfaces[1]));
		dropdown.select = selected;
		addChild(dropdown);
		
		setLexerface(lexerfaces[0]);
		dropdown.activeData = lexerface;
		
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
	
	function selected(list:ListBox) {
		setLexerface(list.activeData);
	}
	
	function setLexerface(lf:LexerInterface) {
		lexerface = lf;
		
		while (roots.length > 0) roots.pop();
		for (key in nodeMap.keys()) nodeMap.remove(key);
		for (ruleset in lexerface.getRulesets()) {
			roots.push({ node: StateNode.processGraphState(ruleset.state, nodeMap), ruleset: ruleset });
		}
		visualizeNodes();
		lex();
	}
	
	function addedToStage(e:Event) {
		loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, uncaughtError);
		
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
		lex();
	}
	
	function lex() {
		if (source == null) return;
		lexerface.update(source, sourceName);
		tokenizeStart();
	}
	
	//function updateLexerface(source:String, fileName:String) {
		//lexer = new HaxeLexer(ByteData.ofString(source), fileName);
		//lexer = Type.createInstance(currentLexer.type, [ByteData.ofString(source), fileName]);
		//lexer.stateCallback = stateCallback;
	//}
	
	//function stateCallback(state:State, position:Int, input:Int) {
	function stepCallback(step:StateNode.Step, node:StateNode) {
		nodeVis.highlight(node);
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
		editor.clearTags();
		//nodeMap = new Map<State, StateNode>();
		
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
		
		var tag = null;
		try {
			//tag = lexer.token(currentLexer.ruleset);
			//tag = lexer.token(currentLexer.ruleset);
			tag = lexerface.nextTag();
		} catch(e:UnexpectedChar) {
			L.error(e);
			return true;
		}
		
		updateProgress();
		
		//L.debug(tag);
		
		//var end = token == null || current.tok == TokenDef.Eof;
		var end = tag == null;
		if (end) return true;
		
		//editor.addToken(current, steps);
		editor.addTag(tag);
		
		return false;
	}
	
	function updateProgress() {
		//progressBarProgress = current == null ? 1 : current.pos.max/source.length;
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
		
		//parseSource();
		
		//screenshot();
		//visualizeNodes();
		//delayedUpdate.reset();
		//delayedUpdate.start();
	}
	
	/*
	function parseSource() {
		var ast = parser.parse();
		for (decl in ast.decls) {
			editor.addTag(new HaxeTags.DeclarationTag(decl));
			switch (decl) {
				case EClass( { data: data } ):
					for (field in data) {
						editor.addTag(new HaxeTags.FieldTag(field));
					}
				default:
			}
		}
	}
	*/
	
	function screenshot(source:DisplayObject) {
		var bounds = source.getBounds(source);
		
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
		
		data.drawWithQuality(source, m, null, null, null, true, StageQuality.HIGH_16X16);
		
		//addChild(new Bitmap(data));
		
		var bytes = new ByteArray();
		data.encode(data.rect, new PNGEncoderOptions(), bytes);
		var f = new FileReference();
		f.save(bytes, "screenshot.png");
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
			var ps = stepHandler.posMap[pos];
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
		for (root in roots) {
			nodeVis.visualize(root.node, root.ruleset.name);
		}
		
		updateNodeVis();
		
		//screenshot();
	}
	
	function update(e:Event) {
		resizeToContent();
		updateSource(editor.text, "<editor>");
	}
	
	function updateNodeVis() {
		if (stage == null) return;
		var bounds = nodeVis.getBounds(nodeVis);
		visContainer.x = stage.stageWidth-bounds.right;
	}
	
	function keyDown(e:KeyboardEvent) {
		if (e.ctrlKey) {
			switch (e.keyCode) {
				case Keyboard.N: screenshot(nodeVis);
				case Keyboard.M: screenshot(this);
			}
		}
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
		dropdown.x = stage.stageWidth-5;
	}
	
}