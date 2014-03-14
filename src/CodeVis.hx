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
import haxeparser.Data.Token;
import haxeparser.Data.TokenDef;
import haxeparser.HaxeLexer;

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
	var current:Token;
	var totalTokens:Int;
	
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
		
		addEventListener(Event.ADDED_TO_STAGE, addedToStage);
		addEventListener(Event.RESIZE, stageResize);
		
		if (ExternalInterface.available) {
			ExternalInterface.addCallback("locationHashChanged", locationHashChanged);
			ExternalInterface.call("swfInit");
		} else {
			filePath = defaultPath;
			loadPath();
		}
	}
	
	function addedToStage(e:Event) {
		var file = loaderInfo.parameters.file;
		if (file != null) {
			L.info("Loading file", file);
		}
		stage.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, uncaughtError);
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
		lexer = new HaxeLexer(ByteData.ofString(source), fileName);
	}
	
	function fileLoaded(data:String) {
		editor.text = data;
		resizeToContent();
		
		updateLexer(data, filePath);
		tokenizeStart();
	}
	
	
	function tokenizeStart() {
		tokenizeStop();
		totalTokens = 0;
		editor.clearTokens();
		addEventListener(Event.ENTER_FRAME, tokenizeRun);
	}
	
	function tokenizeRun(e:Event) {
		var start = Lib.getTimer();
		var end = false;
		while (Lib.getTimer()-start < 10) {
			end = nextToken();
			totalTokens++;
			if (end) break;
		}
		if (end) tokenizeStop();
	}
	
	function nextToken():Bool {
		current = lexer.token(HaxeLexer.tok);
		var end = current == null || current.tok == TokenDef.Eof;
		if (end) return true;
		
		editor.addToken(current);
		
		return false;
	}
	
	function tokenizeStop() {
		if (!hasEventListener(Event.ENTER_FRAME)) return;
		L.info("Tokens lexed:", totalTokens);
		removeEventListener(Event.ENTER_FRAME, tokenizeRun);
	}
	
	function resizeToContent() {
		if (ExternalInterface.available) ExternalInterface.call("resizeSWF", width, height);
	}
	
	function stageResize(e:Event = null) {
		//redrawConsoleBar();
		console.resize(stage.stageWidth, consoleHeight);
	}
	
}