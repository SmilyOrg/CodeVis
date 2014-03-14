package edit;

import com.furusystems.slf4hx.loggers.Logger;
import com.furusystems.slf4hx.Logging;
import flash.display.Graphics;
import flash.display.Sprite;
import flash.events.EventPhase;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFieldAutoSize;
import flash.text.TextFormat;
import flash.ui.Mouse;
import flash.ui.MouseCursor;
import haxeparser.Data.Token;

class TokenTag extends Sprite {
	
	private static var L:Logger = Logging.getLogger(TokenTag);
	
	var token:Token;
	var info:TextField;
	var steps:Array<StateNode.Step>;
	
	public function new(token:Token, steps:Array<StateNode.Step>) {
		this.token = token;
		this.steps = steps;
		
		super();
		
		addEventListener(MouseEvent.MOUSE_OVER, rollOver);
		addEventListener(MouseEvent.MOUSE_OUT, rollOut);
		
	}
	
	function updateInfo() {
		info.text = steps.join("\n")+"\n"+""+token.tok;
		info.y = -info.height;
	}
	
	function rollOver(e:MouseEvent) {
		Mouse.cursor = MouseCursor.IBEAM;
		removeInfo();
		info = new TextField();
		info.defaultTextFormat = new TextFormat("_typewriter");
		info.autoSize = TextFieldAutoSize.LEFT;
		info.background = true;
		updateInfo();
		addChild(info);
	}
	function rollOut(e:MouseEvent) {
		Mouse.cursor = MouseCursor.AUTO;
		removeInfo();
	}
	
	function removeInfo() {
		if (info != null) {
			removeChild(info);
			info = null;
		}
	}
	
	public function destroy() {
		removeInfo();
		removeEventListener(MouseEvent.MOUSE_OVER, rollOver);
		removeEventListener(MouseEvent.MOUSE_OUT, rollOut);
	}
	
	public function redraw(w:Float, h:Float) {
		var g:Graphics = graphics;
		g.clear();
		g.beginFill(0xFFFFFF, 0.2);
		g.drawRoundRect(0, 0, w, h, 8, 8);
	}
	
}