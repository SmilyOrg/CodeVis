package ;

import com.furusystems.slf4hx.bindings.ILogBinding;
import flash.display.BlendMode;
import flash.display.Graphics;
import flash.display.Shape;
import flash.display.Sprite;
import flash.events.Event;
import flash.geom.Rectangle;
import flash.text.engine.CFFHinting;
import flash.text.engine.FontLookup;
import flash.text.engine.RenderingMode;
import flash.text.engine.TabAlignment;
import flash.text.engine.TextLine;
import flashx.textLayout.compose.TextFlowLine;
import flashx.textLayout.container.ContainerController;
import flashx.textLayout.container.ScrollPolicy;
import flashx.textLayout.container.TextContainerManager;
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

class Console extends Sprite implements ILogBinding {

	var config:Configuration;
	var format:TextLayoutFormat;
	
	var container:ContainerController;
	//var container:TextContainerManager;
	//var editManager:EditManager;
	
	var textflow:TextFlow;
	
	var overlay:Shape = new Shape();
	
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
		//format.cffHinting = CFFHinting.HORIZONTAL_STEM;
		format.color = 0xF8F8F2;
		
		
		container = new ContainerController(this);
		//container = new TextContainerManager(this, config);
		container.renderingMode = RenderingMode.CFF;
		container.paddingTop = container.paddingBottom = container.paddingLeft = container.paddingRight = 10;
		
		container.verticalScrollPolicy = ScrollPolicy.ON;
		
		text = "Console";
		
	}
	
	/* INTERFACE com.furusystems.slf4hx.bindings.ILogBinding */
	
	public function print(owner:Dynamic, level:String, str:String):Void {
		var paragraph = new ParagraphElement();
		paragraph.lineHeight = 14;
		
		var span = new SpanElement();
		span.replaceText(0, 0, level+"  "+str);
		
		paragraph.addChild(span);
		textflow.addChild(paragraph);
		
		textflow.flowComposer.updateAllControllers();
		container.verticalScrollPosition = Math.POSITIVE_INFINITY;
	}
	
	//public function focus() {
		//editManager.setFocus();
	//}
	
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
		textflow.tabStops = stops;
		textflow.flowComposer.addController(container);
		textflow.flowComposer.updateAllControllers();
		
		return v;
	}
	
	public function resize(w:Float, h:Float) {
		container.setCompositionSize(w-container.paddingRight, h);
		textflow.flowComposer.updateAllControllers();
	}
	
	
}