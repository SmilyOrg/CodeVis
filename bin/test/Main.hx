package;


import flash.display.Sprite;
import flash.events.Event;
import motion.Actuate;
import motion.easing.Quad;


class Main extends Sprite {
	
	
	public function new () {
		
		super ();
		
		initialize ();
		construct ();
		
	}
	
	
	private function animateCircle (circle:Sprite):Void {
		
		var duration = 1.5 + Math.random () * 4.5;
		var targetX = Math.random () * stage.stageWidth;
		var targetY = Math.random () * stage.stageHeight;
		
		Actuate.tween (circle, duration, { x: targetX, y: targetY }, false).ease (Quad.easeOut).onComplete (animateCircle, [ circle ]);
		
	}
	
	
	private function construct ():Void {
		
		for (i in 0...80) {
			
			var creationDelay = Math.random () * 10;
			Actuate.timer (creationDelay).onComplete (createCircle);
			
		}
		
	}
	
	
	private function createCircle ():Void {
		
		var size = 5 + Math.random () * 35 + 20;
		var circle = new Sprite ();
		
		circle.graphics.beginFill (Std.int (Math.random () * 0xFFFFFF));
		circle.graphics.drawCircle (0, 0, size);
		circle.alpha = 0.2 + Math.random () * 0.6;
		circle.x = Math.random () * stage.stageWidth;
		circle.y = Math.random () * stage.stageHeight;
		
		addChildAt (circle, 0);
		animateCircle (circle);
		
	}
	
	
	private function initialize ():Void {
		
		stage.addEventListener (Event.ACTIVATE, stage_onActivate);
		stage.addEventListener (Event.DEACTIVATE, stage_onDeactivate);
		
	}
	
	
	
	
	// Event Handlers
	
	
	
	
	private function stage_onActivate (event:Event):Void {
		
		Actuate.resumeAll ();
		
	}
	
	
	private function stage_onDeactivate (event:Event):Void {
		
		Actuate.pauseAll ();
		
	}
	
	
}