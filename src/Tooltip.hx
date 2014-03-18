package ;
import flash.display.Graphics;
import flash.display.Sprite;
import flash.text.engine.FontLookup;
import flashx.textLayout.container.TextContainerManager;
import flashx.textLayout.edit.EditingMode;
import flashx.textLayout.formats.LineBreak;
import flashx.textLayout.formats.TextLayoutFormat;

class Tooltip extends Sprite {
	
	var tcm:TextContainerManager;
	
	public var text(get, set):String;
	
	public function new() {
		super();
		
		var config = TextContainerManager.defaultConfiguration.clone();
		var format = new TextLayoutFormat();
		format.fontFamily = "Inconsolata";
		format.fontSize = 14;
		format.fontLookup = FontLookup.EMBEDDED_CFF;
		format.lineBreak = LineBreak.EXPLICIT;
		format.color = 0xF8F8F2;
		config.textFlowInitialFormat = format;
		
		tcm = new TextContainerManager(this, config);
		tcm.editingMode = EditingMode.READ_ONLY;
		
		mouseEnabled = mouseChildren = false;
	}
	
	public function get_text():String {
		return tcm.getText();
	}
	
	public function set_text(v:String):String {
		tcm.setText(v);
		tcm.compositionWidth = Math.NaN;
		tcm.compositionHeight = Math.NaN;
		tcm.updateContainer();
		
		var bounds = tcm.getContentBounds();
		
		var g:Graphics = graphics;
		g.clear();
		g.beginFill(0x272822, 0.7);
		g.drawRoundRect(-6, -6, bounds.width+12, bounds.height+12, 12, 12);
		
		return v;
	}
	
}