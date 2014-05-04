package ;

class TestEscape {

	public function new() {
		var s:String = "abc \n \r \t \x21 \u003F \u{0021}123";
		var s:String = 'abc \n \r \t \x21 \u003F \u{0021}123';
	}
	
}