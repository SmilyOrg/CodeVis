package edit;

import com.furusystems.slf4hx.loggers.Logger;
import com.furusystems.slf4hx.Logging;
import flash.display.Graphics;
import flash.display.Sprite;
import flash.events.MouseEvent;
import flash.geom.Rectangle;
import flash.ui.Mouse;
import flash.ui.MouseCursor;

enum Type {
	Filled;
	Outline;
}

class Tag extends Sprite {
	
	private static var L:Logger = Logging.getLogger(Tag);
	
	//var token:Token;
	//var info:TextField;
	//var steps:Array<StateNode.Step>;
	//var info:Info<T>;
	
	public var min:Int;
	public var max:Int;
	
	var tooltip:Tooltip;
	var type = Filled;
	//var type = Outline;
	
	public function new(min, max) {
		this.min = min;
		this.max = max;
		
		super();
		
		addEventListener(MouseEvent.MOUSE_OVER, rollOver);
		addEventListener(MouseEvent.MOUSE_OUT, rollOut);
	}
	
	function getInfo() {
		return "";
	}
	
	function getColor() {
		return 0xFFFFFF;
	}
	
	function updateInfo() {
		//info.text = steps.join("\n")+"\n"+""+token.tok;
		//info.y = -info.height;
		//tooltip.text = (steps.join("\n")+"\n"+""+token.tok);
		tooltip.text = getInfo();
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
	
	//public function redraw(w:Float, h:Float) {
	public function redraw(selection:Array<Rectangle>) {
		
		//var color = token == null ? 0xFFFFFF : Theme.getTokenColor(token);
		//var color = 0xFFFFFF;
		
		var g = graphics;
		g.clear();
		
		var r = 8;
		
		var color = getColor();
		
		switch (type) {
			case Filled:
				g.beginFill(color, 0.3);
				drawRoundSelection(selection, r);
				
				//g.drawRoundRect(0, 0, w, h, r, r);
				//for (rect in selection) g.drawRoundRect(rect.x, rect.y, rect.width, rect.height, r, r);
				
				
			case Outline:
				//var bw = 12, bh = 6;
				var bw = 6, bh = selection[0].height;
				
				// TODO outline only the AABB of all the selection rects
				
				//g.beginFill(color, 0.4);
				//g.drawRoundRectComplex(0, -bh, bw, bh, 2, 2, 0, 0);
				//g.endFill();
				
				g.beginFill(color, 0.4);
				g.drawRoundRectComplex(-bw, 0, bw, bh, 2, 2, 2, 2);
				g.endFill();
				
				g.lineStyle(1, color, 0.3);
				if (selection.length > 1) {
					var outline:Rectangle = selection[0];
					for (rect in selection) {
						outline = outline.union(rect);
					}
					g.drawRoundRect(outline.x, outline.y, outline.width, outline.height, r, r);
				} else {
					drawRoundSelection(selection, r);
				}
		}
	}
	
	public function drawRoundSelection(selection:Array<Rectangle>, r:Float) {
		var g = graphics;
		 if (selection.length == 1) {
			var rect = selection[0];
			g.drawRoundRect(rect.x, rect.y, rect.width, rect.height, r, r);
		} else if (selection.length > 1) {
			var y:Float = selection[0].y;
			for (i in 0...selection.length) {
				var rect = selection[i];
				var tl = i > 0 ? Math.abs(selection[i-1].left-rect.left) > 1e-9 ? r : 0 : r;
				var tr = i > 0 ? Math.abs(selection[i-1].right-rect.right) > 1e-9 ? r : 0 : r;
				var bl = i < selection.length-1 ? Math.abs(selection[i+1].left-rect.left) > 1e-9 ? r : 0 : r;
				var br = i < selection.length-1 ? Math.abs(selection[i+1].right-rect.right) > 1e-9 ? r : 0 : r;
				g.drawRoundRectComplex(rect.x, y, rect.width, rect.height+rect.y-y, tl, tr, bl, br);
				y = rect.bottom;
			}
		}
	}
	
}