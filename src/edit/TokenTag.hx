package edit;

import com.furusystems.slf4hx.loggers.Logger;
import com.furusystems.slf4hx.Logging;
import flash.display.Graphics;
import flash.display.Sprite;
import flash.events.EventPhase;
import flash.events.MouseEvent;
import flash.text.engine.FontLookup;
import flash.text.TextField;
import flash.text.TextFieldAutoSize;
import flash.text.TextFormat;
import flash.ui.Mouse;
import flash.ui.MouseCursor;
import flashx.textLayout.container.TextContainerManager;
import flashx.textLayout.edit.EditingMode;
import flashx.textLayout.formats.LineBreak;
import flashx.textLayout.formats.TextLayoutFormat;
import haxeparser.Data.Token;

class TokenTag extends Sprite {
	
	private static var L:Logger = Logging.getLogger(TokenTag);
	
	var token:Token;
	//var info:TextField;
	var tooltip:Tooltip;
	var steps:Array<StateNode.Step>;
	
	public function new(token:Token, steps:Array<StateNode.Step>) {
		this.token = token;
		this.steps = steps;
		
		super();
		
		addEventListener(MouseEvent.MOUSE_OVER, rollOver);
		addEventListener(MouseEvent.MOUSE_OUT, rollOut);
		
	}
	
	function updateInfo() {
		//info.text = steps.join("\n")+"\n"+""+token.tok;
		//info.y = -info.height;
		tooltip.text = (steps.join("\n")+"\n"+""+token.tok);
		tooltip.y = -tooltip.height;
	}
	
	function rollOver(e:MouseEvent) {
		Mouse.cursor = MouseCursor.IBEAM;
		removeInfo();
		/*
		info = new TextField();
		info.defaultTextFormat = new TextFormat("_typewriter");
		info.autoSize = TextFieldAutoSize.LEFT;
		info.background = true;
		//addChild(info);
		*/
		
		initInfo();
		updateInfo();
		
		e.stopPropagation();
		e.stopImmediatePropagation();
	}
	function rollOut(e:MouseEvent) {
		Mouse.cursor = MouseCursor.AUTO;
		removeInfo();
		e.stopPropagation();
		e.stopImmediatePropagation();
	}
	
	function initInfo() {
		tooltip = new Tooltip();
		addChild(tooltip);
	}
	
	function removeInfo() {
		if (tooltip != null) {
			removeChild(tooltip);
			tooltip = null;
		}
		//if (info != null) {
			//removeChild(info);
			//info = null;
		//}
	}
	
	public function destroy() {
		removeInfo();
		removeEventListener(MouseEvent.MOUSE_OVER, rollOver);
		removeEventListener(MouseEvent.MOUSE_OUT, rollOut);
	}
	
	public function redraw(w:Float, h:Float) {
		
		var color = token == null ? 0xFFFFFF : Theme.getTokenColor(token);
		
		var g:Graphics = graphics;
		g.clear();
		g.beginFill(color, 0.2);
		//g.beginFill(0x000000, 0);
		//g.lineStyle(1, color, 0.2);
		g.drawRoundRect(0, 0, w, h, 8, 8);
	}
	
}