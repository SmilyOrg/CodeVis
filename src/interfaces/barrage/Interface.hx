package interfaces.barrage;

import byte.ByteData;
import com.furusystems.barrage.parser.Data;
import com.furusystems.barrage.parser.BarrageLexer;
import com.furusystems.barrage.parser.BarrageParser;
import com.furusystems.slf4hx.loggers.Logger;
import com.furusystems.slf4hx.Logging;
import StepHandler;

class Lexerface implements LexerInterface {
	private static var L:Logger = Logging.getLogger(Lexerface);
	
	var sh:StepHandler;
	var lexer:BarrageLexer;
	public function new(sh) {
		this.sh = sh;
	}
	public function getRulesets() { return BarrageLexer.generatedRulesets; }
	public function update(source:String, sourceName:String) {
		if (lexer != null) {
			lexer = null;
		}
		lexer = new BarrageLexer(ByteData.ofString(source), sourceName);
		sh.init(lexer);
	}
	public function nextTag() {
		sh.pretoken();
		try {
			var token:Token = lexer.token(BarrageLexer.tok);
			return token == null || token.tok == Eof ? null : new TokenTag(sh.posttoken(), token);
		} catch (e:LexerError) {
			L.error(e.msg);
		}
		return null;
	}
}

class TokenTag extends StepTag {
	var token:Token;
	public function new(steps, token) {
		this.token = token;
		// Max position -1, because the last position is the exiting position
		super(steps, token.pos.pmin, token.pos.pmax-1);
	}
	override function getInfo() {
		return super.getInfo() + token.tok;
	}
	override function getColor() {
		return switch (token.tok) {
			
			case Kwd(_): Theme.directive;
			
			case Const(CIdent(ident)): Theme.constant;
			
			//case Const(CString(_)): Theme.string;
			
			case Const(CInt(_)),
			     Const(CFloat(_)): Theme.number;
				 
			//case Comment(_),
			case CommentLine(_): Theme.comment;
				 
			//case Sharp(_),
			     //Include(_, _): Theme.directive;
			
			
			default: Theme.foreground;
		}
	}
}