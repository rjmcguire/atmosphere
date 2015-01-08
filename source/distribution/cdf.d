/++
Comulative density functions
+/
module distribution.cdf;

import std.algorithm;
import std.traits;
import std.range;
import std.mathspecial;


/++
Comulative density function interface
+/
interface CDF(T)
{
	/++
	Call operator
	+/
	T opCall(T x);
}

///
unittest 
{
	import std.traits, std.mathspecial;

	class NormalCDF : CDF!real
	{
		real opCall(real x)
		{
			return normalDistribution(x);
		}
	}

	auto cdf = new NormalCDF;
	auto x = cdf(0.1);
	assert(isNormal(x));
}


/++
Class to compute cumulative density function as integral of it's probability density function
+/
abstract class NumericCDF(T) : CDF!T
{
	import scid.calculus : Result, integrate;
	import distribution.pdf;

	private PDF!T pdf;
	private T a, epsRel, epsAbs;
	private T[] subdivisions;
	private T[] partials;

	/++
	Constructor
    Params:
		pdf     = The PDF to _integrate.
		a	= (optional) The lower limit of integration.
		epsRel  = (optional) The requested relative accuracy.
		epsAbs  = (optional) The requested absolute accuracy.
	See_also: [struct Result](https://github.com/kyllingstad/scid/blob/a9f3916526e4bf9a4da35d14a969e1abfa17a496/source/scid/types.d)
	+/
	this(PDF!T pdf, T[] subdivisions, T a = -T.infinity, T epsRel = 1e-6, T epsAbs = 0)
	in {
		assert(!subdivisions.empty);
		assert(subdivisions.all!isFinite);
		assert(subdivisions.all!(s => s > a));
		assert(subdivisions.isSorted);
		assert(subdivisions.findAdjacent.empty);
	}
	body {
		this.pdf = pdf;
		this.a = a;
		this.epsRel = epsRel;
		this.epsAbs = epsAbs;
		this.subdivisions = subdivisions;
		this.partials = new T[subdivisions.length];
		partials.front = pdf.integrate(a, subdivisions.front, epsRel, epsAbs);
		foreach(i, ref partial; partials[1..$])
			partial = pdf.integrate(subdivisions[i], subdivisions[i+1], epsRel, epsAbs);
	}

	/++
	Call operator
	+/
	final T opCall(T x)
	{
		if(x == -T.infinity)
			return 0;
		if(x == T.infinity)
			return 1;
		if(x.isNaN)
			return x;
		immutable i = subdivisions.length - subdivisions.assumeSorted.trisect(x)[2].length;
		return sum(partials[0..i])
			+ pdf.integrate(i ? subdivisions[i-1] : a, x, epsRel, epsAbs);
	}
}

/// Numeric cumulative density function of standard normal distribution
unittest
{
	import std.traits, std.mathspecial;
	import distribution.pdf;

	class NormalPDF : PDF!real
	{
		real opCall(real x)
		{
			// 1/sqrt(2 PI)
			enum c = 0.398942280401432677939946L;
			return c * exp(-0.5f * x * x);
		}
	}

	class NormalCDF : NumericCDF!real
	{
		this()
		{
			super(new NormalPDF, [-3, -1, 0, 1, 3]);
		}
	}

	auto cdf = new NormalCDF;

	assert(approxEqual(cdf(1.3), normalDistribution(1.3)));
}


/++
Class to compute complementary cumulative density function as integral of it's probability density function
+/
abstract class NumericCCDF(T) : CDF!T
{
	import scid.calculus : Result, integrate;
	import distribution.pdf;

	private PDF!T pdf;
	private T b, epsRel, epsAbs;
	private T[] subdivisions;
	private T[] partials;

	/++
	Constructor
    Params:
		pdf     = The PDF to _integrate.
		b	= (optional) The upper limit of integration.
		epsRel  = (optional) The requested relative accuracy.
		epsAbs  = (optional) The requested absolute accuracy.
	See_also: [struct Result](https://github.com/kyllingstad/scid/blob/a9f3916526e4bf9a4da35d14a969e1abfa17a496/source/scid/types.d)
	+/
	this(PDF!T pdf, T[] subdivisions, T b = T.infinity, T epsRel = 1e-6, T epsAbs = 0)
	in {
		assert(!subdivisions.empty);
		assert(subdivisions.all!isFinite);
		assert(subdivisions.all!(s => s < b));
		assert(subdivisions.isSorted);
		assert(subdivisions.findAdjacent.empty);
	}
	body {
		this.pdf = pdf;
		this.b = b;
		this.epsRel = epsRel;
		this.epsAbs = epsAbs;
		this.subdivisions = subdivisions;
		this.partials = new T[subdivisions.length];
		partials.back = pdf.integrate(subdivisions.back, b, epsRel, epsAbs);
		foreach(i, ref partial; partials[0..$-1])
			partial = pdf.integrate(subdivisions[i], subdivisions[i+1], epsRel, epsAbs);
	}

	/++
	Call operator
	+/
	final T opCall(T x)
	{
		if(x == -T.infinity)
			return 0;
		if(x == T.infinity)
			return 1;
		if(x.isNaN)
			return x;
		immutable i = subdivisions.length - subdivisions.assumeSorted.trisect(x)[0].length;
		return sum(partials[$-i..$])
			+ pdf.integrate(x, i ? subdivisions[$-i] : b, epsRel, epsAbs);
	}
}

/// Numeric complementary cumulative density function of standard normal distribution
unittest
{
	import std.traits, std.mathspecial;
	import distribution.pdf;

	class NormalPDF : PDF!real
	{
		real opCall(real x)
		{
			// 1/sqrt(2 PI)
			enum c = 0.398942280401432677939946L;
			return c * exp(-0.5f * x * x);
		}
	}

	class NormalCCDF : NumericCCDF!real
	{
		this()
		{
			super(new NormalPDF, [-3, -1, 0, 1, 3]);
		}
	}

	auto ccdf = new NormalCCDF;

	assert(approxEqual(ccdf(1.3), 1-normalDistribution(1.3)));
}


/++
Gamma CDF
+/
final class GammaCDF(T) : CDF!T
	if(isFloatingPoint!T)
{
	private T shape, scale;

	/++
	Constructor
	Params:
		shape = gamma shape parameter
		scale = gamma scale parameter
	+/
	this(T shape, T scale)
	in {
		assert(shape.isNormal);
		assert(shape > 0);
		assert(scale.isNormal);
		assert(scale > 0);
	}
	body {
		this.shape = shape;
		this.scale = scale;
	}

	T opCall(T x)
	{
		return x <= 0 ? 0 : gammaIncomplete(shape, x / scale);
	}
}


///
unittest 
{
	auto cdf = new GammaCDF!double(3, 2);
	auto x = cdf(0.1);
	assert(isNormal(x));
}


/++
Inverse-gamma CDF
+/
final class InverseGammaCDF(T) : CDF!T
	if(isFloatingPoint!T)
{
	private T shape, scale;

	/++
	Constructor
	Params:
		shape = gamma shape parameter
		scale = gamma scale parameter
	+/
	this(T shape, T scale)
	in {
		assert(shape.isNormal);
		assert(shape > 0);
		assert(scale.isNormal);
		assert(scale > 0);
	}
	body {
		this.shape = shape;
		this.scale = scale;
	}

	T opCall(T x)
	{
		return x <= 0 ? 0 : gammaIncomplete(shape, scale / x);
	}
}

///
unittest 
{
	auto cdf = new InverseGammaCDF!double(3, 2);
	auto x = cdf(0.1);
	assert(isNormal(x));
}


/++
Generalized gamma CDF
+/
final class GeneralizedGammaCDF(T) : CDF!T
	if(isFloatingPoint!T)
{
	private T shape, power, scale, gammaShape;

	/++
	Constructor
	Params:
		shape = shape parameter
		power = power parameter
		scale = scale parameter
	+/
	this(T shape, T power, T scale = 1)
	in {
		assert(shape.isNormal);
		assert(shape > 0);
		assert(power.isFinite);
		assert(scale.isNormal);
		assert(scale > 0);
	}
	body {
		this.shape = shape;
		this.power = power;
		this.scale = scale;
		this.gammaShape = gamma(shape);
		assert(gammaShape.isNormal);
	}

	T opCall(T x)
	{
		return x <= 0 ? 0 : gammaIncomplete(shape, pow(x / scale, power)) / gammaShape;
	}
}

///
unittest 
{
	auto cdf = new GeneralizedGammaCDF!double(3, 2, 0.5);
	auto x = cdf(0.1);
	assert(isNormal(x));
}


/++
Inverse Gaussian PDF
+/
final class InverseGaussianCDF(T) : CDF!T
	if(isFloatingPoint!T)
{
	private T omega, chi, psi;

	///Constructor
	this(T chi, T psi)
	in {
		assert(chi.isNormal);
		assert(chi > 0);
		assert(psi.isNormal);
		assert(psi > 0);
	}
	body {
		this.chi = chi;
		this.psi = psi;
		this.omega = sqrt(chi * psi);
	}

	T opCall(T x)
	{
		if(x <= 0)
			return 0;
		immutable a = sqrt(chi / x);
		immutable b = sqrt(psi * x);
		return normalDistribution(b - a) - exp(2*omega) * normalDistribution(-(a+b));
	}
}

///
unittest 
{
	auto cdf = new InverseGaussianCDF!double(3, 2);
	auto x = cdf(0.1);
	assert(isNormal(x));
}