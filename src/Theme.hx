package ;
import haxeparser.Data.Token;

class Theme {

	static public function getTokenColor(token:Token) {
		return switch(token.tok) {
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
		};
	}
	
}