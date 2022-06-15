package dn.debug;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
#end

class MemTrack {
	@:noCompletion
	public static var allocs : Map<String, { total:Float, calls:Int }> = new Map();

	public static var firstMeasure = -1.;

	/** Measure a block or a function call memory usage **/
	public static macro function measure( e:Expr ) {
		var id = Context.getLocalModule()+"."+Context.getLocalMethod()+": ";
		id += switch e.expr {
			case ECall(e, params):
				haxe.macro.ExprTools.toString(e)+"()";

			case EBlock(_):
				"{block}";

			case _:
				"<unknown>";
		}

		return macro {
			if( dn.debug.MemTrack.firstMeasure<0 )
				dn.debug.MemTrack.firstMeasure = haxe.Timer.stamp();
			var old = hl.Gc.stats().currentMemory;

			$e;

			var m = dn.M.fmax( 0, hl.Gc.stats().currentMemory - old );

			if( !dn.debug.MemTrack.allocs.exists($v{id}) )
				dn.debug.MemTrack.allocs.set($v{id}, { total:0, calls:0 });
			var alloc = dn.debug.MemTrack.allocs.get( $v{id} );
			alloc.total += m;
			alloc.calls++;
		}
	}

	/** Reset current allocs tracking **/
	public static function reset() {
		allocs = new Map();
		firstMeasure = -1;
	}



	static inline function padRight(str:String, minLen:Int, padChar=" ") {
		while( str.length<minLen )
			str+=padChar;
		return str;
	}

	/** Print report to standard output **/
	public static function report(?printer:String->Void) {
		if( printer==null )
			printer = (v)->trace(v);

		var all = [];
		for(a in allocs.keyValueIterator())
			all.push({id: a.key, mem:a.value });
		all.sort( (a,b) -> -Reflect.compare(a.mem.total, b.mem.total) );

		if( all.length==0 ) {
			printer("MemTrack has nothing to report.");
			return;
		}

		printer("MEMTRACK REPORT");
		var t = haxe.Timer.stamp() - firstMeasure;
		printer('Elapsed time: ${M.pretty(t,1)}s');
		var table = [];
		for(a in all)
			table.push([
				a.id,
				dn.M.unit(a.mem.total),
				dn.M.unit(a.mem.total/t)+"/s",
				// dn.M.unit(a.mem.total/a.mem.calls)+"/call",
				// a.mem.calls+" calls",
			]);

		// Build visual table
		var colWidths : Array<Int> = [];
		for(line in table) {
			for(i in 0...line.length)
				if( !M.isValidNumber(colWidths[i]) )
					colWidths[i] = line[i].length;
				else
					colWidths[i] = M.imax(colWidths[i], line[i].length);
		}
		printer(colWidths.join(","));
		for(line in table) {
			for(i in 0...line.length)
				line[i] = padRight(line[i], colWidths[i]);
			printer("| " + line.join("  |  ") + " |");
		}

		reset();
	}
}