package edit;

import com.furusystems.slf4hx.loggers.Logger;
import com.furusystems.slf4hx.Logging;
import flash.display.BlendMode;
import flash.display.Graphics;
import flash.display.Shape;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.text.engine.CFFHinting;
import flash.text.engine.FontLookup;
import flash.text.engine.RenderingMode;
import flash.text.engine.TabAlignment;
import flash.text.engine.TextLine;
import flash.ui.Keyboard;
import flash.utils.Object;
import flashx.textLayout.compose.TextFlowLine;
import flashx.textLayout.container.ContainerController;
import flashx.textLayout.conversion.ConverterBase;
import flashx.textLayout.conversion.ITextImporter;
import flashx.textLayout.conversion.TextConverter;
import flashx.textLayout.edit.EditManager;
import flashx.textLayout.edit.IEditManager;
import flashx.textLayout.edit.SelectionFormat;
import flashx.textLayout.edit.SelectionState;
import flashx.textLayout.elements.Configuration;
import flashx.textLayout.elements.FlowLeafElement;
import flashx.textLayout.elements.IConfiguration;
import flashx.textLayout.elements.ParagraphElement;
import flashx.textLayout.elements.SpanElement;
import flashx.textLayout.elements.TextFlow;
import flashx.textLayout.events.FlowOperationEvent;
import flashx.textLayout.formats.LineBreak;
import flashx.textLayout.formats.TabStopFormat;
import flashx.textLayout.formats.TextLayoutFormat;
import flashx.undo.UndoManager;
import haxeparser.Data.Token;
import haxeparser.Data.TokenDef;

using StringTools;

class PlainSpanImporter extends ConverterBase implements ITextImporter {

	public function new() {
		super();
	}
	
	var _configuration:IConfiguration;
	
	@:extern @:keep public var configuration(default, default):IConfiguration;
	
	@:getter(configuration) public function get_configuration():IConfiguration {
		return _configuration;
	}
	
	@:setter(configuration) public function set_configuration(value:IConfiguration):Void {
		_configuration = value;
	}
	
	public function importToFlow(source:Object):TextFlow {
		var s = cast(source, String);
		if (s == null) return null;
		
		//s = s.replace("doge", "wow");
		
		var tf:TextFlow = new TextFlow(_configuration);
		var para:ParagraphElement = new ParagraphElement();
		var span:SpanElement = new SpanElement();
		span.replaceText(0, 0, s);
		para.addChild(span);
		tf.addChild(para);
		//tf.addChild(span);
		
		// Mark partial last paragraph (string doesn't end in paragraph terminator)
		if (useClipboardAnnotations && 
		   (s.lastIndexOf("\x000A", s.length - 2) < 0 || 
			s.lastIndexOf("\x000D\x000A", s.length - 3) < 0))
		{
			var lastLeaf:FlowLeafElement = tf.getLastLeaf();
			lastLeaf.setStyle(ConverterBase.MERGE_TO_NEXT_ON_PASTE, "true");
			lastLeaf.parent.setStyle(ConverterBase.MERGE_TO_NEXT_ON_PASTE, "true");
			tf.setStyle(ConverterBase.MERGE_TO_NEXT_ON_PASTE, "true");
		}
		
		return tf;
	}
	
}

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
	
	var valid:Bool = true;
	
	public var text(get, set):String;
	
	public function new() {
		super();
		
		TextConverter.addFormatAt(0, "plainText", PlainSpanImporter, null, "air:text");
		
		config = new Configuration();
		config.manageTabKey = true;
		config.manageEnterKey = false;
	
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
		
		textDisplay.addEventListener(KeyboardEvent.KEY_DOWN, keyDown);
		
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
		
		initTextFlow();
		
		text = "";
		
	}
	
	function initTextFlow() {
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
		
		//textflow = TextConverter.importToFlow(v, TextConverter.PLAIN_TEXT_FORMAT, config);
		
		textflow = new TextFlow(config);
		
		var paragraph = new ParagraphElement();
		textflow.addChild(paragraph);
		
		textflow.format = format;
		textflow.interactionManager = editManager;
		textflow.tabStops = stops;
		textflow.flowComposer.addController(container);
		textflow.flowComposer.updateAllControllers();
		textflow.addEventListener(FlowOperationEvent.FLOW_OPERATION_COMPLETE, textChanged);
	}
	
	
	public function focus() {
		editManager.setFocus();
	}
	
	function keyDown(e:KeyboardEvent) {
		switch (e.keyCode) {
			case Keyboard.ENTER:
				editManager.insertText("\n");
		}
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
	
	public function addToken(token:Token, steps:Array<StateNode.Step>) {
		var min = token.pos.min;
		var max = token.pos.max;
		
		///*
		var boundsMin = getCharBoundsAtPosition(min);
		var boundsMax = getCharBoundsAtPosition(max);
		
		if (boundsMin == null || boundsMax == null) return;
		
		var tag:TokenTag = new TokenTag(token, steps);
		tag.x = boundsMin.x;
		tag.y = boundsMin.y-2;
		tag.redraw(boundsMax.x-boundsMin.x, boundsMin.height+2);
		tokenDisplay.addChild(tag);
		tokenTags.push(tag);
		//*/
		
		var paragraph:ParagraphElement = cast textflow.getChildAt(0);
		
		//L.debug(min, max, textflow.getChildAt(0) == paragraph, text.length);
		
		var spanIndex = paragraph.findChildIndexAtPosition(min);
		var span:SpanElement = cast paragraph.getChildAt(spanIndex);
		var spanStart = span.getAbsoluteStart();
		var rmin = min-spanStart;
		var rmax = max-spanStart;
		if (rmin > 0) {
			// Whitespace before token
			var pretokenSpan = span.shallowCopy(0, rmin);
			paragraph.addChildAt(spanIndex, pretokenSpan);
			spanIndex++;
		}
		
		// Merge sibling spans until the current span is long enough
		///*
		var spanLen = span.textLength;
		while (rmax > spanLen) {
			var next = span.getNextSibling();
			if (next == null) return;
			span.replaceText(spanLen, spanLen, next.getText());
			paragraph.removeChild(next);
			spanLen = span.textLength;
		}
		//*/
		
		
		var tokenSpan = span.shallowCopy(rmin, rmax);
		
		tokenSpan.color = switch(token.tok) {
			
			case Kwd(KwdImport),
			     Kwd(KwdClass),
				 Kwd(KwdEnum),
				 Kwd(KwdAbstract),
				 Kwd(KwdTypedef),
				 Kwd(KwdPackage): 0x66D9EF;
				 
			case Kwd(_),
			     Const(CIdent("trace")): 0xF92772;
				 
			case Const(CIdent(ident)):
				var c = ident.charAt(0);
				(c.toUpperCase() == c) ? 0xFF9901 : 0xF8F8F2;
				
			case Const(CString(_)): 0xE6DB74;
			
			case Const(CInt(_)),
			     Const(CFloat(_)): 0x777777;
				 
			case Const(_): 0xF8F8F2;
			
			case CommentLine(_),
			     Comment(_): 0x75715E;
				 
			case Sharp(_): 0xA6E22A;
			
			default: 0xF8F8F2;
		}
		
		//L.debug(0, rmax, span.textLength, span.getText());
		span.replaceText(0, rmax, "");
		paragraph.addChildAt(spanIndex, tokenSpan);
		
		//textflow.flowComposer.updateAllControllers();
		
		invalidate();
		
		//textflow.flowComposer.updateAllControllers();
		//textflow.flowComposer.composeToPosition(max);
		
		//L.info(spanIndex, spanStart, min, max, tokenSpan.getText());
		
		/*
		code { color: #F8F8F2; }
		code .identifier { color:#F8F8F2; }
		code .type { color:#FF9901; }
		code .keyword { color:#F92772; }
		code .directive { color:#66D9EF; }
		code .constant { color:#AE81FF; }
		code .comment { color:#75715E; }
		code .string { color:#E6DB74; }
		code .macro { color:#A6E22A; }
		code .inactive { color:#75715E; }
		code .num { color:#777777; }
		*/
		
		//var tokenFormat = new TextLayoutFormat(format);
		//tokenFormat.color = 0xFF0000;
		//var selection = new SelectionState(textflow, min, max);
		//cast(textflow.interactionManager, IEditManager).applyLeafFormat(tokenFormat, selection);
		
	}
	
	function invalidate() {
		if (valid) {
			valid = false;
			addEventListener(Event.EXIT_FRAME, validate, false, 0, true);
		}
	}
	
	function validate(e:Event) {
		valid = true;
		removeEventListener(Event.EXIT_FRAME, validate);
		textflow.flowComposer.updateAllControllers();
		container.verticalScrollPosition = Math.POSITIVE_INFINITY;
	}
	
	public function updateFlow() {
		textflow.flowComposer.updateAllControllers();
	}

	function getCharBoundsAtPosition(pos:Int) {
		container.flowComposer.composeToPosition(pos);
		var flowLine = container.flowComposer.findLineAtPosition(pos);
		if (flowLine == null) return null;
		var line = flowLine.getTextLine(true);
		//var lineBounds = line.getBounds(overlay);
		var lineBounds = flowLine.getBounds();
		var atomIndex = line.getAtomIndexAtCharIndex(pos);
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
		var span = new SpanElement();
		span.replaceText(0, 0, v);
		
		var paragraph:ParagraphElement = cast textflow.getChildAt(0);
		
		paragraph.replaceChildren(0, paragraph.numChildren-1, span);
		
		textflow.flowComposer.updateAllControllers();
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