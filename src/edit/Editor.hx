package edit;

import com.furusystems.slf4hx.loggers.Logger;
import com.furusystems.slf4hx.Logging;
import flash.display.BlendMode;
import flash.display.Graphics;
import flash.display.Shape;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.text.engine.CFFHinting;
import flash.text.engine.FontLookup;
import flash.text.engine.RenderingMode;
import flash.text.engine.TabAlignment;
import flash.text.engine.TextLine;
import flashx.textLayout.compose.TextFlowLine;
import flashx.textLayout.container.ContainerController;
import flashx.textLayout.conversion.TextConverter;
import flashx.textLayout.edit.EditManager;
import flashx.textLayout.edit.SelectionFormat;
import flashx.textLayout.elements.Configuration;
import flashx.textLayout.elements.ParagraphElement;
import flashx.textLayout.elements.SpanElement;
import flashx.textLayout.elements.TextFlow;
import flashx.textLayout.events.FlowOperationEvent;
import flashx.textLayout.formats.LineBreak;
import flashx.textLayout.formats.TabStopFormat;
import flashx.textLayout.formats.TextLayoutFormat;
import flashx.undo.UndoManager;
import haxeparser.Data.Token;

class Editor extends Sprite {

	private static var L:Logger = Logging.getLogger(Editor);
	
	var config:Configuration;
	var format:TextLayoutFormat;
	
	var container:ContainerController;
	var editManager:EditManager;
	
	var textflow:TextFlow;
	
	var textDisplay:Sprite = new Sprite();
	var overlay:Shape = new Shape();
	
	var tokenTags:Array<TokenTag> = [];
	var tokenDisplay:Sprite = new Sprite();
	
	public var text(get, set):String;
	
	public function new() {
		super();
		
		config = new Configuration();
		config.manageTabKey = true;
	
		format = new TextLayoutFormat();
		//format.fontFamily = "Source Code Pro";
		format.fontFamily = "Inconsolata";
		format.fontSize = 14;
		//format.fontSize = 11;
		format.renderingMode = RenderingMode.CFF;
		format.fontLookup = FontLookup.EMBEDDED_CFF;
		format.lineBreak = LineBreak.EXPLICIT;
		format.cffHinting = CFFHinting.HORIZONTAL_STEM;
		format.color = 0xF8F8F2;
		
		container = new ContainerController(textDisplay, 300, 200);
		container.renderingMode = RenderingMode.CFF;
		container.paddingTop = container.paddingBottom = container.paddingLeft = container.paddingRight = 20;
		
		container.setCompositionSize(Math.NaN, Math.NaN);
		
		editManager = new EditManager(new UndoManager());
		editManager.focusedSelectionFormat = new SelectionFormat(0x4A8DF2, 0.25, "normal");
		
		addChild(textDisplay);
		addChild(overlay);
		
		tokenDisplay.addEventListener(MouseEvent.MOUSE_DOWN, tokenMouseDown, true);
		addChild(tokenDisplay);
		
		text = "";
		
	}
	
	public function focus() {
		editManager.setFocus();
	}
	
	public function tokenMouseDown(e:MouseEvent) {
		var p = textDisplay.globalToLocal(e.target.localToGlobal(new Point(e.localX, e.localY)));
		e.localX = p.x;
		e.localY = p.y;
		textDisplay.dispatchEvent(e);
	}
	
	public function clearTokens() {
		var tag;
		while ((tag = tokenTags.pop()) != null) {
			tag.destroy();
			tokenDisplay.removeChild(tag);
		}
	}
	
	public function addToken(token:Token) {
		var min = token.pos.min;
		var max = token.pos.max;
		
		var boundsMin = getCharBoundsAtPosition(min);
		var boundsMax = getCharBoundsAtPosition(max);
		
		if (boundsMin == null || boundsMax == null) return;
		
		var tag:TokenTag = new TokenTag(token);
		tag.x = boundsMin.x;
		tag.y = boundsMin.y-2;
		tag.redraw(boundsMax.x-boundsMin.x, boundsMin.height+2);
		tokenDisplay.addChild(tag);
		tokenTags.push(tag);
		
	}
	
	function getCharBoundsAtPosition(pos:Int) {
		var flowLine = container.flowComposer.findLineAtPosition(pos);
		if (flowLine == null) return null;
		var line = flowLine.getTextLine(true);
		//var lineBounds = line.getBounds(overlay);
		var lineBounds = flowLine.getBounds();
		var atomIndex = line.getAtomIndexAtCharIndex(pos-flowLine.absoluteStart);
		var atomBounds = line.getAtomBounds(atomIndex);
		atomBounds.x += line.x;
		atomBounds.y += line.y+line.descent;
		return atomBounds;
	}
	
	public function clearMarks() {
		var g:Graphics = overlay.graphics;
		g.clear();
	}
	
	public function markLine(index:Int) {
		var flowLine:TextFlowLine = container.flowComposer.getLineAt(index);
		if (flowLine == null) return;
		
		var textLine:TextLine = flowLine.getTextLine();
		if (textLine == null) return;
		
		var rect:Rectangle = textLine.getBounds(this);
		
		var padding:Float = 2;
		var g:Graphics = overlay.graphics;
		g.beginFill(0xFF0000, 0.2);
		//g.drawRect(rect.x-padding, rect.y-2-padding, rect.width+padding*2, rect.height+padding*2);
		
		var offset:Float = 2;
		var width:Float = 4;
		g.drawRect(rect.x-offset-width, rect.y-1-padding, width, rect.height-1+padding*2);
	}
	
	public function get_text():String {
		return textflow.getText();
	}
	
	public function set_text(v:String):String {
		if (textflow != null) {
			textflow.removeEventListener(FlowOperationEvent.FLOW_OPERATION_COMPLETE, textChanged);
			textflow.format = null;
			textflow.interactionManager = null;
			textflow.flowComposer.removeAllControllers();
		}
		
		var stops:Array<TabStopFormat> = [];
		for (i in 0...100) {
			var fmt:TabStopFormat = new TabStopFormat();
			fmt.position = (i+1)*20;
			fmt.alignment = TabAlignment.START;
			stops.push(fmt);
		}
		
		textflow = TextConverter.importToFlow(v, TextConverter.PLAIN_TEXT_FORMAT, config);
		textflow.format = format;
		textflow.interactionManager = editManager;
		textflow.tabStops = stops;
		textflow.flowComposer.addController(container);
		textflow.flowComposer.updateAllControllers();
		textflow.addEventListener(FlowOperationEvent.FLOW_OPERATION_COMPLETE, textChanged);
		
		return v;
	}
	
	private function textChanged(e:FlowOperationEvent) {
		dispatchEvent(new Event(Event.CHANGE));
	}
	
	public function resize(w:Float, h:Float) {
		container.setCompositionSize(w, h);
		textflow.flowComposer.updateAllControllers();
	}
	
	
}