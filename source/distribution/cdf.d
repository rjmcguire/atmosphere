/++
Comulative density functions
+/
module distribution.cdf;

import std.traits;
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
