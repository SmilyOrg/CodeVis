package interfaces.haxe;
import byte.ByteData;
import com.furusystems.slf4hx.loggers.Logger;
import com.furusystems.slf4hx.Logging;
import edit.Tag;
import haxe.macro.Expr.Field;
import haxeparser.Data;
import haxeparser.HaxeLexer;
import StepHandler;

class Lexerface implements LexerInterface {
	private static var L:Logger = Logging.getLogger(Lexerface);
	
	var sh:StepHandler;
	var lexer:HaxeLexer;
	public function new(sh) {
		this.sh = sh;
	}
	public function getRulesets() { return HaxeLexer.generatedRulesets; }
	public function update(source:String, sourceName:String) {
		if (lexer != null) {
			lexer = null;
		}
		lexer = new HaxeLexer(ByteData.ofString(source), sourceName);
		sh.init(lexer);
	}
	public function nextTag() {
		sh.pretoken();
		try {
			var token = lexer.token(HaxeLexer.tok);
			return token == null || token.tok == TokenDef.Eof ? null : new TokenTag(sh.posttoken(), token);
		} catch (e:LexerError) {
			L.error(e.msg, '${e.pos.file} ${e.pos.min}:${e.pos.max}');
		}
		return null;
	}
}

class TokenTag extends StepTag {
	var token:Token;
	public function new(steps, token) {
		this.token = token;
		// Max position -1, because the last position is the exiting position
		super(steps, token.pos.min, token.pos.max-1);
	}
	override function getInfo() {
		return super.getInfo() + token.tok;
	}
	override function getColor() {
		return switch(token.tok) {
			case Kwd(KwdImport),
			     Kwd(KwdClass),
				 Kwd(KwdEnum),
				 Kwd(KwdAbstract),
				 Kwd(KwdTypedef),
				 Kwd(KwdPackage): Theme.identifier;
				 
			case Kwd(_),
			     Const(CIdent("trace")): Theme.keyword;
				 
			case Const(CIdent(ident)):
				var c = ident.charAt(0);
				(c.toUpperCase() == c) ? Theme.type : Theme.identifier;
				
			case Const(CString(_)): Theme.string;
			
			case Const(CInt(_)),
			     Const(CFloat(_)): Theme.number;
				 
			case Const(_): Theme.constant;
			
			case CommentLine(_),
			     Comment(_): Theme.comment;
				 
			case Sharp(_): Theme.directive;
			
			default: Theme.foreground;
		};
	}
}

class DeclarationTag extends Tag {
	var decl:TypeDef;
	public function new(decl) {
		this.decl = decl;
		switch (decl) {
			case EImport(sl, _):
				super(sl[0].pos.min, sl[sl.length-1].pos.max);
			case EClass( { data: data } ):
				if (data.length > 0) {
					super(data[0].pos.min, data[data.length-1].pos.max);
				} else {
					super(0, 0);
				}
			default:
				super(0, 0);
				trace("Unsupppp");
		}
		type = Outline;
	}
	override function getInfo() {
		var s = super.getInfo();
		s += switch (decl) {
			case EImport(sl, _):
				"import!";
			case EClass( { data: data } ):
				data.length + " fields";
			default:
				trace("Unsupported decl");
				"N/A";
		};
		return s;
	}
	//override function getColor() {
		//return Theme.getTokenColor(token);
	//}
}

class FieldTag extends Tag {
	var field:Field;
	public function new(field) {
		this.field = field;
		super(field.pos.min, field.pos.max);
		type = Outline;
	}
	override function getInfo() {
		var s = super.getInfo();
		s += field;
		return s;
	}
	//override function getColor() {
		//return Theme.getTokenColor(token);
	//}
}