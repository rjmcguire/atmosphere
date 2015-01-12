module atmosphere.utilities;

import core.stdc.string;
import std.traits;
import std.math;

package:

import cblas;
import simple_matrix;

version(LDC)
{
	pragma(LDC_inline_ir)
	    R inlineIR(string s, R, P...)(P);
}


/**
Computes accurate sum of binary logarithms of input range `r`.
Will be avalible in std.numeric with with DMD 2.068.
 */
public // @@BUG@@
T sumOfLog2s(T)(T[] r) 
{
	import std.compiler;
	static if(version_minor < 68)
		import core.stdc.tgmath : frexp;
	else
		import std.math : frexp; 
	import std.traits : Unqual;

    long exp = 0;
    Unqual!(typeof(return)) x = 1; 
    foreach (e; r)
    {
        if (e < 0)
            return typeof(return).nan;
        int lexp = void;
		static if(version_minor < 68)
    	    x *= frexp(e, &lexp);
    	else
    	    x *= frexp(e, lexp);
        exp += lexp;
        if (x < 0.5) 
        {
            x *= 2;
            exp--;
        }
    }
    return exp + log2(x);
}

version(LDC)
{
	T sum(T)(in T[] a)
	{
		T ret = 0;
		foreach(j; 0..a.length)
			static if(is(Unqual!T == double))
			ret = inlineIR!(`
				%r = fadd fast double %0, %1
				ret double %r`, double)(ret, a[j]);
			else
			static if(is(Unqual!T == float))
			ret = inlineIR!(`
				%r = fadd fast float %0, %1
				ret float %r`, float)(ret, a[j]);
			else
			ret += a[j];
		return ret;
	}
}
else
{
	T sum(T)(in T[] a)
	{
		T ret = 0;
		foreach(j; 0..a.length)
			ret += a[j];
		return ret;
	}
}

unittest {
	import std.range : iota, array;
	static import std.algorithm;
	foreach(i; 0.0..30.0)
		assert(std.algorithm.sum(iota(i)) == iota(i).array.sum);
}


///
auto avg(Range)(Range range)
{
	return range.sum / range.length;
}

///
void normalize(F)(F[] range)
{
	immutable s = range.sum;
	assert(s.isFinite);
	assert(s > 0);
	foreach(ref elem; range)
		elem /= s;
}

///
void gemv(M, F)(in M m, in F[] a, F[] b)
in {
	assert (m.width == a.length);
	assert (m.height == b.length);
}
body {

	static if(is(M : Matrix!(T), T))
	{
		assert(m.ptr);
		assert(m.shift >= m.width);
		cblas.gemv(
			Order.RowMajor,
			Transpose.NoTrans,
			cast(blasint)b.length,
		 	cast(blasint)a.length,
			1,//F
			m.ptr,
			cast(blasint)m.shift,
			a.ptr,
			1,
			0,//F
			b.ptr,
			1);
	}
	else
	static if(is(M : TransposedMatrix!T, T))
	{
		assert(m.matrix.ptr);
		assert(m.matrix.shift >= m.matrix.width);
		cblas.gemv(
			Order.RowMajor,
			Transpose.Trans,
			cast(blasint)a.length,
		 	cast(blasint)b.length,
			1.0,
			m.matrix.ptr,
			cast(blasint)m.matrix.shift,
			a.ptr,
			1,
			0.0,
			b.ptr,
			1);
	}
	else
	{
		import std.string : format;
		static assert(0, format("gemv for %s not implimented", M.stringof));
	}
}

unittest
{
	const ar = [
	 1.000,  6.000,   2.000,
	 8.000,  3.000,   7.000,
	 3.000,  5.000,   2.000,
	53.000, 23.000, 123.000,
	];
	auto m = Matrix!(const double)(ar.ptr, 4, 3);
	const a = [
	42.000,
	35.000,
	12.000,
	];
	auto b = new double[4];
	gemv(m, a, b);
	assert(b == [ 
	 276.000,
	 525.000,
	 325.000,
	4507.000,
	]);

}

unittest
{
	const ar = [
  	1.000,   8.000,  3.000,  53.000,
  	6.000,   3.000,  5.000,  23.000,
  	2.000,   7.000,  2.000, 123.000,
	];
	auto m = Matrix!(const double)(ar.ptr, 3, 4);
	const a = [
	42.000,
	35.000,
	12.000,
	];
	auto b = new double[4];
	gemv(m.transposed, a, b);
	assert(b == [ 
	 276.000,
	 525.000,
	 325.000,
	4507.000,
	]);

}


version(LDC)
{
	T dotProduct(T)(in T[] a, in T[] b)
	{
		T ret = 0;
		foreach(j; 0..a.length)
			static if(is(Unqual!T == double))
			ret = inlineIR!(`
				%d = fmul fast double %1, %2
				%r = fadd fast double %0, %d
				ret double %r`, double)(ret, a[j], b[j]);
			else
			static if(is(Unqual!T == float))
			ret = inlineIR!(`
				%d = fmul fast float %1, %2
				%r = fadd fast float %0, %d
				ret float %r`, float)(ret, a[j], b[j]);
			else
			ret += a[j] * b[j];
		return ret;
	}
}
else
{
	T dotProduct(T)(in T[] a, in T[] b)
	{
		T ret = 0;
		foreach(j; 0..a.length)
			ret += a[j] * b[j];
		return ret;
	}
}

version(LDC)
{
	T dotProductInverse(T)(in T[] a, in T[] b)
	{
		T ret = 0;
		foreach(j; 0..a.length)
			static if(is(Unqual!T == double))
			ret = inlineIR!(`
				%d = fdiv fast double %1, %2
				%r = fadd fast double %0, %d
				ret double %r`, double)(ret, a[j], b[j]);
			else
			static if(is(Unqual!T == float))
			ret = inlineIR!(`
				%d = fdiv fast float %1, %2
				%r = fadd fast float %0, %d
				ret float %r`, float)(ret, a[j], b[j]);
			else
			ret += a[j] * b[j];
		return ret;
	}
}
else
{
	T dotProductInverse(T)(in T[] a, in T[] b)
	{
		T ret = 0;
		foreach(j; 0..a.length)
			ret += a[j] / b[j];
		return ret;
	}
}


version(LDC)
{
	T dotProductInverse2(T)(in T[] a, in T[] b, T[] c)
	{
		T ret = 0;
		foreach(j; 0..a.length)
		{
			static if(is(Unqual!T == double))
			{
				ret = inlineIR!(`
					%d = fdiv fast double %1, %2
					%r = fadd fast double %0, %d
					ret double %r`, double)(ret, b[j], a[j]);
				c[j] = a[j] - b[j];
			}
			else
			static if(is(Unqual!T == float))
			{
				ret = inlineIR!(`
					%d = fdiv fast float %1, %2
					%r = fadd fast float %0, %d
					ret float %r`, float)(ret, b[j], a[j]);
				c[j] = a[j] - b[j];
			}
			else
			{
				ret += b[j] / a[j];
				c[j] = a[j] - b[j];
			}
		}
		return ret;
	}
}
else
{
	T dotProductInverse2(T)(in T[] a, in T[] b, T[] c)
	{
		T ret = 0;
		foreach(j; 0..a.length)
		{
			ret += b[j] / a[j];
			c[j] = a[j] - b[j];
		}
		return ret;
	}
}


/**
Struct that represent flat matrix.
Useful for sliding windows.
*/
struct MatrixColumnsSlider(F)
{
	Matrix!F _matrix;
	Matrix!F matrix;

	this(size_t maxHeight, size_t maxWidth, size_t height)
	{
		_matrix = Matrix!F(maxHeight, maxWidth);
		_matrix.width = _matrix.shift;
		matrix.ptr = _matrix.ptr;
		matrix.shift = _matrix.shift;
		matrix.height = height;
	}

	void popFrontN(size_t n)
	in 
	{
		assert(n <= matrix.width, "n > matrix.width");
	}
	body 
	{
		if(n < matrix.width)
		{
			matrix.width -= n;
			matrix.ptr += n;
		}
		else
		{ 
			reset;
		}
	}

	void popFront()
	{
		popFrontN(1);
	}

	void reset()
	{
		matrix.ptr = _matrix.ptr;
		matrix.width = 0;
	}

	void putBackN(size_t n)
	in
	{
		assert(matrix.shift >= matrix.width+n);
	}
	body 
	{
		if(n > _matrix.ptrEnd-matrix.ptrEnd)
		{
			bringToFront();
		}
		matrix.width += n;
	}

	void putBack()
	{
		putBackN(1);
	}

	void bringToFront()
	{
		if(matrix.width)
		{
			memmove(_matrix.ptr, matrix.ptr, (matrix.shift*matrix.height)*F.sizeof);					
		}
		matrix.ptr = _matrix.ptr;
	}
}
