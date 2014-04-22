package interfaces;

import byte.ByteData;
import PrintfParser;
import templo.Lexer;
import templo.Token;

class PrintfLexerface implements LexerInterface {
	var sh:StepHandler;
	var lexer:PrintfLexer;
	public function new(sh) {
		this.sh = sh;
	}
	public function getRulesets() { return PrintfLexer.generatedRulesets; }
	public function update(source:String, sourceName:String) {
		if (lexer != null) {
			lexer = null;
		}
		lexer = new PrintfLexer(ByteData.ofString(source), sourceName);
		sh.init(lexer);
	}
	public function nextTag() {
		sh.pretoken();
		var token = lexer.token(PrintfLexer.tok);
		return token == null || token == PToken.Eof ? null : new StepHandler.StepTag(sh.posttoken(), 0, 0);
	}
}

class TemploLexerface implements LexerInterface {
	var sh:StepHandler;
	var lexer:templo.Lexer;
	public function new(sh) {
		this.sh = sh;
	}
	public function getRulesets() { return templo.Lexer.generatedRulesets; }
	public function update(source:String, sourceName:String) {
		if (lexer != null) {
			lexer = null;
		}
		lexer = new templo.Lexer(ByteData.ofString(source), sourceName);
		sh.init(lexer);
	}
	public function nextTag() {
		sh.pretoken();
		var token = lexer.token(templo.Lexer.element);
		return token == null || token.tok == templo.Token.TokenDef.Eof ? null : new StepHandler.StepTag(sh.posttoken(), token.pos.pmin, token.pos.pmax);
	}
}
