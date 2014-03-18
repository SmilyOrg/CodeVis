package ;
import com.furusystems.slf4hx.loggers.Logger;
import com.furusystems.slf4hx.Logging;
import flash.display.Sprite;
import flash.events.MouseEvent;
import flash.geom.Point;
import flash.text.engine.FontLookup;
import flash.ui.Mouse;
import flashx.textLayout.container.TextContainerManager;
import flashx.textLayout.edit.EditingMode;
import flashx.textLayout.elements.Configuration;
import flashx.textLayout.formats.LineBreak;
import flashx.textLayout.formats.TextLayoutFormat;
import motion.Actuate;

using StringTools;

class DisplayNode extends Sprite {
	
	private static var L:Logger = Logging.getLogger(DisplayNode);
	
	static public var margin:Float = 5;
	
	var node:StateNode;
	
	public var mark:Bool = false;
	public var contentWidth:Float = 0;
	
	public function new(node:StateNode) {
		this.node = node;
		super();
		redraw();
		//addEventListener(MouseEvent.MOUSE_OVER, rollOver);
		buttonMode = true;
		//addEventListener(MouseEvent.MOUSE_DOWN, mouseDown);
	}
	public function select() {
		redraw(0xFFCC00);
		scaleX = scaleY = 5;
		Actuate.tween(this, 0.3, { scaleX: 1, scaleY: 1 } );
	}
	public function deselect() {
		redraw();
	}
	public function destroy() {
		//removeEventListener(MouseEvent.MOUSE_OVER, rollOver);
		node = null;
	}
	function redraw(color:Int = 0xFFFFFF) {
		var g = graphics;
		g.clear();
		g.beginFill(color, 1);
		g.drawCircle(0, 0, 3);
		g.endFill();
		if (node.state.final > -1) {
			g.lineStyle(1, color, 1);
			g.drawCircle(0, 0, 5);
		}
	}
	//function rollOver(e:Event) {
		//L.debug(node, contentWidth);
	//}
	//function mouseDown(e:MouseEvent) {
		//stage.addEventListener(MouseEvent.MOUSE_UP, mouseUp);
		//startDrag();
	//}
	//function mouseUp(e:MouseEvent) {
		//stage.removeEventListener(MouseEvent.MOUSE_UP, mouseUp);
		//stopDrag();
	//}
}

class NodeVis extends Sprite {
	
	private static var L:Logger = Logging.getLogger(NodeVis);
	
	var nodeClearance:Float = 10;
	var depthClearance:Float = 5;
	
	var labelConfig:Configuration;
	
	var node:StateNode;
	
	var displayMap:Map<StateNode, DisplayNode>;
	var nodes = new Array<DisplayNode>();
	var selected = new Array<DisplayNode>();
	var edgeLabels = new Map<StateNode.Edge, Sprite>();
	
	var drag:DisplayNode;
	var dragOffset:Point = new Point();
	
	public function new() {
		super();
		labelConfig = TextContainerManager.defaultConfiguration.clone();
		
		var format = new TextLayoutFormat();
		format.fontFamily = "Inconsolata";
		format.fontSize = 11;
		format.fontLookup = FontLookup.EMBEDDED_CFF;
		format.lineBreak = LineBreak.EXPLICIT;
		//format.cffHinting = CFFHinting.HORIZONTAL_STEM;
		format.color = 0xF8F8F2;
		format.backgroundColor = 0x7D7D44;
		format.backgroundAlpha = 1;
		labelConfig.textFlowInitialFormat = format;
		
		addEventListener(MouseEvent.MOUSE_DOWN, mouseDown);
		
		//mouseEnabled = mouseChildren = false;
		
	}
	
	function mouseDown(e:MouseEvent) {
		if (Type.getClass(e.target) != DisplayNode) return;
		stage.addEventListener(MouseEvent.MOUSE_UP, mouseUp);
		stage.addEventListener(MouseEvent.MOUSE_MOVE, mouseMove);
		drag = cast e.target;
		dragOffset.x = drag.mouseX;
		dragOffset.y = drag.mouseY;
		Mouse.hide();
	}
	function mouseMove(e:MouseEvent) {
		drag.x = mouseX-dragOffset.x;
		drag.y = mouseY-dragOffset.y;
		drawEdges(node, displayMap);
		e.updateAfterEvent();
	}
	function mouseUp(e:MouseEvent) {
		mouseMove(e);
		stage.removeEventListener(MouseEvent.MOUSE_UP, mouseUp);
		stage.removeEventListener(MouseEvent.MOUSE_MOVE, mouseMove);
		Mouse.show();
	}
	
	public function clear() {
		var g = graphics;
		g.clear();
		var node;
		clearSelection();
		while ((node = nodes.pop()) != null) {
			node.destroy();
			removeChild(node);
		}
		var label;
		//while ((label = edgeLabels.pop()) != null) {
			//removeChild(label);
		//}
		for (con in edgeLabels) {
			removeChild(con);
		}
		edgeLabels = new Map<StateNode.Edge, Sprite>();
	}
	
	public function clearSelection() {
		var node;
		while ((node = selected.pop()) != null) {
			node.deselect();
		}
	}
	
	public function select(node:StateNode) {
		var d = displayMap[node];
		if (d != null) {
			d.select();
			selected.push(d);
		}
	}
	
	public function visualize(node:StateNode) {
		this.node = node;
		
		clear();
		
		var g = graphics;
		
		displayMap = new Map<StateNode, DisplayNode>();
		
		createNodes(node, displayMap);
		positionNodes(node, displayMap);
		drawEdges(node, displayMap);
		
	}
	
	function createNodes(node:StateNode, displayMap:Map<StateNode, DisplayNode>, parent:DisplayNode = null, level:Int = 0):DisplayNode {
		
		var g = graphics;
		
		var d = new DisplayNode(node);
		nodes.push(d);
		addChild(d);
		//if (parent == null) {
			//addChild(d);
		//} else {
			//parent.addChild(d);
		//}
		
		displayMap[node] = d;
		
		for (edge in node.targets) {
			var td = displayMap[edge.drain];
			if (td == null) {
				td = createNodes(edge.drain, displayMap, d, level+1);
				d.contentWidth += td.contentWidth;
			}
			//g.lineStyle(1, 0xFFFFFF, 0.2);
			//g.moveTo(d.x, d.y);
			//g.lineTo(td.x, td.y);
		}
		
		if (d.contentWidth == 0) d.contentWidth = nodeClearance+DisplayNode.margin*2+level*depthClearance;
		
		return d;
	}
	
	function clearMarks() {
		for (node in nodes) node.mark = false;
	}
	
	function positionNodes(node:StateNode, displayMap:Map<StateNode, DisplayNode>, parent:DisplayNode = null) {
		
		if (parent == null) clearMarks();
		
		var d = displayMap[node];
		d.mark = true;
		
		var num = node.targets.length;
		var tcx:Float = 0;
		for (i in 0...num) {
			var edge = node.targets[i];
			var td = displayMap[edge.drain];
			var old = td.mark;
			
			if (!td.mark) {
				//td.x = d.x+tcx-(d.contentWidth-td.contentWidth)/2;
				td.x = d.x+tcx-d.contentWidth+td.contentWidth;
				td.y = d.y+30;
				td.y += Math.log(1+num)*20;
				tcx += td.contentWidth;
				positionNodes(edge.drain, displayMap, d);
			}
			
			var a = old ? td : d;
			var b = old ? d : td;
			drawEdge(edge, a, b);
			
		}
		
	}
	
	function drawEdges(node:StateNode, displayMap:Map<StateNode, DisplayNode>, parent:DisplayNode = null) {
		
		if (parent == null) {
			clearMarks();
			var g = graphics;
			g.clear();
		}
		
		var d = displayMap[node];
		d.mark = true;
		
		for (edge in node.targets) {
			var td = displayMap[edge.drain];
			
			var a = td.mark ? td : d;
			var b = td.mark ? d : td;
			drawEdge(edge, a, b);
			
			if (!td.mark) drawEdges(edge.drain, displayMap, d);
		}
	}
	
	function drawEdge(edge:StateNode.Edge, da:DisplayNode, db:DisplayNode) {
		
		var g = graphics;
		
		var a = globalToLocal(da.localToGlobal(new Point()));
		var b = globalToLocal(db.localToGlobal(new Point()));
		
		g.lineStyle(0, 0xFFFFFF, 0.2);
		g.moveTo(a.x, a.y);
		
		if (da == db) {
			var selfRadius = 15;
			g.drawCircle(a.x, a.y+selfRadius, selfRadius);
			addEdgeLabel(edge, a.x+selfRadius, a.y+selfRadius, 0.3);
		} else {
			var d = b.subtract(a);
			var n = d.clone(); n.normalize(1);
			
			//g.lineTo(b.x, b.y);
			
			var mp = a.add(b);
			mp.setTo(mp.x/2, mp.y/2);
			var perp = d.clone(); perp.normalize(perp.length*0.3);
			
			var cp = new Point(mp.x-perp.y, mp.y+perp.x);
			
			g.curveTo(cp.x, cp.y, b.x, b.y);
			
			//if (!old) {
				//g.lineTo(tp.x, p.y);
			//} else {
				//g.lineTo(p.x, tp.y);
			//}
			//g.lineTo(tp.x, tp.y);
			
			//var angle = 0;
			var angle = -0.5;
			
			var ld = b.subtract(cp);
			ld.normalize(-15);
			var dist = 8;
			//ld.x += dist*Math.cos(angle);
			//ld.y += dist*Math.sin(angle);
		
			addEdgeLabel(edge, b.x+ld.x, b.y+ld.y, angle);
		}
	}
	
	function addEdgeLabel(edge:StateNode.Edge, x:Float, y:Float, angle:Float) {
		//var label = new TextField();
		//label.defaultTextFormat = new TextFormat("Arial", 10, 0xFFFFFF);
		//label.autoSize = TextFieldAutoSize.LEFT;
		//label.text = name;
		//label.x = x;
		//label.y = y;
		//label.selectable = false;
		//label.rotation = angle*180/Math.PI;
		//addChild(label);
		//labels.push(label);
		
		var con = edgeLabels[edge];
		if (con == null) {
			con = new Sprite();
			var rot = new Sprite();
			
			var label = edge.label;
			var postfix = switch (edge.label) {
				case " ": "space";
				case '"': "quote";
				case "'": "apostrophe";
				case ",": "comma";
				case ".": "dot";
				case "-": "minus";
				case "_": "underscore";
				case ":": "colon";
				case ";": "semicolon";
				case "`": "backtick";
				default: null;
			}
			if (postfix != null) label += ' ($postfix)';
			
			
			var tcm = new TextContainerManager(rot, labelConfig);
			tcm.editingMode = EditingMode.READ_ONLY;
			tcm.compositionWidth = Math.NaN;
			tcm.compositionHeight = Math.NaN;
			tcm.setText(label);
			tcm.updateContainer();
			
			rot.y = -tcm.getContentBounds().height/2;
			
			con.addChild(rot);
			con.mouseChildren = con.mouseEnabled = false;
			addChild(con);
			edgeLabels[edge] = con;
		}
		
		con.x = x;
		con.y = y;
		con.rotation = angle*180/Math.PI;
		
	}
	
	
}