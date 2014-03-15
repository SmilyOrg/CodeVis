package ;

import byte.ByteData;
import com.furusystems.slf4hx.loggers.Logger;
import com.furusystems.slf4hx.Logging;
import edit.Editor;
import flash.display.Graphics;
import flash.display.Sprite;
import flash.display.StageAlign;
import flash.display.StageScaleMode;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.events.UncaughtErrorEvent;
import flash.external.ExternalInterface;
import flash.Lib;
import haxe.Http;
import haxe.Timer;
import haxeparser.Data.Token;
import haxeparser.Data.TokenDef;
import haxeparser.HaxeLexer;
import hxparse.State;
import hxparse.UnexpectedChar;

using StringTools;

class CodeVis extends Sprite {
	
	static function main() {
		var stage = Lib.current.stage;
		stage.scaleMode = StageScaleMode.NO_SCALE;
		stage.align = StageAlign.TOP_LEFT;
		
		stage.addChild(new CodeVis());
	}
	
	private static var L:Logger = Logging.getLogger(CodeVis);
	
	var defaultPath = "test/Main.hx";
	var filePath:String;
	
	var console:Console;
	var editor:Editor;
	
	var lexer:HaxeLexer;
	var tokenizationStart:Int;
	var current:Token;
	var totalTokens:Int;
	
	var nodeMap:Map<State, StateNode>;
	var steps:Array<StateNode.Step>;
	
	var consoleHeight:Float = 100;
	//var consoleVisible:Bool = false;
	//var consoleBar:Sprite;
	
	function new() {
		super();
		
		console = new Console();
		addChild(console);
		
		Logging.logBinding = console;
		
		editor = new Editor();
		editor.y = consoleHeight;
		editor.addEventListener(Event.CHANGE, editorChange);
		addChild(editor);
		
		//consoleBar = new Sprite();
		//consoleBar.buttonMode = true;
		//consoleBar.addEventListener(MouseEvent.MOUSE_DOWN, toggleConsole);
		//addChild(consoleBar);
		
		//toggleConsole();
		//redrawConsoleBar();
		
		#if !expose_lexer_state
			#error "Using this class requires -D expose_lexer_state"
		#end
		
		//L.debug("debug");
		//L.info("info");
		//L.warn("warn");
		//L.error("error");
		//L.fatal("fatal");
		
		addEventListener(Event.ADDED_TO_STAGE, addedToStage);
		addEventListener(Event.RESIZE, stageResize);
		
		if (ExternalInterface.available) {
			defaultPath = "bin/" + defaultPath;
			ExternalInterface.addCallback("locationHashChanged", locationHashChanged);
			ExternalInterface.call("swfInit");
		} else {
			filePath = defaultPath;
			loadPath();
		}
	}
	
	function addedToStage(e:Event) {
		loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, uncaughtError);
		
		var file = loaderInfo.parameters.file;
		if (file != null) {
			L.info("Loading file", file);
		}
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
		updateLexer(editor.text, "<editor>");
		tokenizeStart();
		resizeToContent();
	}
	
	function updateLexer(source:String, fileName:String) {
		if (lexer != null) {
			lexer.stateCallback = null;
		}
		lexer = new HaxeLexer(ByteData.ofString(source), fileName);
		lexer.stateCallback = stateCallback;
	}
	
	function stateCallback(state:State, position:Int, input:Int) {
		var node = StateNode.processGraphState(state, nodeMap);
		
		var step = new StateNode.Step();
		step.state = state;
		step.position = position;
		step.input = input;
		if (node != null && input > -1) step.transition = node.edgeByInput[input];
		
		steps.push(step);
	}
	
	
	function fileLoaded(data:String) {
		data = data.replace("\r", "");
		
		editor.text = data;
		resizeToContent();
		
		updateLexer(data, filePath);
		tokenizeStart();
	}
	
	
	function tokenizeStart() {
		tokenizeStop();
		
		tokenizationStart = Lib.getTimer();
		totalTokens = 0;
		editor.clearTokens();
		nodeMap = new Map<State, StateNode>();
		
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
			current = lexer.token(HaxeLexer.tok);
		} catch(e:UnexpectedChar) {
			L.error(e);
			return true;
		} catch(e:LexerError) {
			L.error(e.msg);
			return true;
		}
		
		var end = current == null || current.tok == TokenDef.Eof;
		if (end) return true;
		
		editor.addToken(current, steps);
		
		return false;
	}
	
	function tokenizeStop() {
		if (!hasEventListener(Event.ENTER_FRAME)) return;
		L.info('Lexed $totalTokens in ${Lib.getTimer()-tokenizationStart}ms');
		removeEventListener(Event.ENTER_FRAME, tokenizeRun);
		editor.updateFlow();
	}
	
	function resizeToContent() {
		if (ExternalInterface.available) ExternalInterface.call("resizeSWF", width, height);
	}
	
	function stageResize(e:Event = null) {
		//redrawConsoleBar();
		console.resize(stage.stageWidth, consoleHeight);
	}
	
}