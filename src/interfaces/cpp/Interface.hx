package interfaces.cpp;
import byte.ByteData;
import com.furusystems.slf4hx.loggers.Logger;
import com.furusystems.slf4hx.Logging;
import cppparser.CppLexer;
import cppparser.Data;
import edit.Tag;
import StepHandler;

class Lexerface implements LexerInterface {
	private static var L:Logger = Logging.getLogger(Lexerface);
	
	var sh:StepHandler;
	var lexer:CppLexer;
	public function new(sh) {
		this.sh = sh;
	}
	public function getRulesets() { return CppLexer.generatedRulesets; }
	public function update(source:String, sourceName:String) {
		if (lexer != null) {
			lexer = null;
		}
		lexer = new CppLexer(ByteData.ofString(source), sourceName);
		sh.init(lexer);
	}
	public function nextTag() {
		sh.pretoken();
		try {
			var token = lexer.token(CppLexer.tok);
			return token == null || token.tok == TokenDef.Eof ? null : new TokenTag(sh.posttoken(), token);
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
			case Kwd(KwdClass),
				 Kwd(KwdEnum),
				 Kwd(KwdTypedef): Theme.identifier;
			
			case Kwd(_): Theme.keyword;
			
			case Const(CIdent(ident)): Theme.identifier;
			
			case Const(CString(_)): Theme.string;
			
			case Const(CInt(_)),
			     Const(CFloat(_)),
				 Const(CLong(_)): Theme.number;
				 
			case Comment(_),
			     CommentLine(_): Theme.comment;
				 
			case Sharp(_),
			     Define(_): Theme.directive;
			
			
			default: Theme.foreground;
		}
	}
}