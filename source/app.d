import std.range : ElementType, hasLength;
import std.traits : isArray, isStaticArray;
import std.typetuple : staticMap, allSatisfy, anySatisfy;

template CommonType(T...)
{
    static if (!T.length)
    {
        alias CommonType = void;
    }
    else static if (T.length == 1)
    {
        static if(is(typeof(T[0])))
        {
            alias CommonType = typeof(T[0]);
        }
        else
        {
            alias CommonType = T[0];
        }
    }
    else static if (is(typeof(true ? T[0].init : T[1].init) U))
    {
        alias CommonType = CommonType!(U, T[2 .. $]);
    }
    else
        alias CommonType = void;
}

template CommonElementType(T...) if (allSatisfy!(hasLength, T))
{
    static if (T.length == 1)
    {
        alias CommonElementType = T[0];
    }
    else static if (T.length >= 2)
    {
        alias CommonElementType = CommonQualifiers!(CommonType, staticMap!(ElementType, T));
    }
    else
    {
        alias CommonElementType = void;
    }
}

template CommonArrayType(T...) if (!is(T[0] == size_t))
{
    alias CommonArrayType = CommonArrayType!(Shortest!T.length, T);
}

template CommonArrayType(size_t length, T...) if (T.length >= 2)
{
    static if (allSatisfy!(isStaticArray, T))
    {
        alias CommonArrayType = CommonQualifiers!(CommonElementType, T)[length];
    }
    else static if (allSatisfy!(isArray, T))
    {
        alias CommonArrayType = CommonQualifiers!(CommonElementType, T)[];
    }
    else
    {
        alias CommonArrayType = void;
    }
}

/**
Returns the type with the biggest `.length` property
*/
template Longest(T...) if (T.length >= 1 && allSatisfy!(hasLength, T))
{
    static if (T.length == 1)
    {
        alias Longest = T[0];
    }
    else static if (T.length == 2)
    {
        static if (T[0].length >= T[1].length)
        {
            alias Longest = T[0];
        }
        else
        {
            alias Longest = T[1];
        }
    }
    else
    {
        alias Longest = Longest!(Longest!(T[0..$/2]), Longest!(T[$/2..$]));
    }
}
/**
Returns the type with the smallest `.length` property
*/
template Shortest(T...) if (T.length >= 1 && allSatisfy!(hasLength, T))
{
    static if (T.length == 1)
    {
        alias Shortest = T[0];
    }
    else static if (T.length == 2)
    {
        static if (T[0].length <= T[1].length)
        {
            alias Shortest = T[0];
        }
        else
        {
            alias Shortest = T[1];
        }
    }
    else
    {
        alias Shortest = Shortest!(Shortest!(T[0..$/2]), Shortest!(T[$/2..$]));
    }
}

enum bool isVoid(T) = !is(T == void);

enum bool hasCommonElementType(T...) = isVoid!(CommonElementType!T);

enum bool hasCommonArrayType(T...) = isVoid!(CommonArrayType!T);

enum bool hasSameLength(T...) = is(Shortest!T == Longest!T);

static string[] demux(size_t begin = 0, size_t end = 1, string before = "", string after = "") pure
{
    string[] elems;
    foreach (i; begin..end)
    {
        import std.format : format;
        elems ~= "%s[%s]%s".format(before, i, after);
    }
    return elems;
}

string atorMix(string target = "arrays", Arrays...)() pure @property
{
    import std.array : join;
    return demux(0, Arrays.length, target, "[]").join(", ");
}

string copyMix(size_t begin = 0, size_t end = 1, string target = "ans")() pure
{
    import std.array : join;
    import std.format : format;
    immutable string str = "[%s]".format(demux(begin, end, target).join(", "));
    return str;
}

auto dive(alias fun, bool convert = true, Arrays...)(Arrays arrays) pure nothrow @nogc
{
    import std.algorithm : reduce, map;
    import std.range : zip;
    auto ans = mixin("zip(" ~ atorMix!("arrays", Arrays) ~ ")").map!(reduce!fun);
    static if (convert)
    {
        alias ResType = CommonElementType!Arrays[Shortest!Arrays.length];
        //return arrayCT!ResType(ans);
        /*
        import std.format : format;
        mixin("ResType res = %s; return res;".format(copyMix!(0, ResType.length, "ans")));
        */
        /*
        import std.algorithm : copy;
        return assumeNoGC(&copy)(ans, res[]);
        */
        
        return assumeNoGC((typeof(ans) a)
        {
            /*
            // Mixin instead of this
            import std.format : format;
            mixin("ResType res = %s; return res;".format(copyMix!(0, ResType.length, "ans")));
            //return res;
            //ResType res = mixin(copyMix!(0, ResType.length, "ans"));
            */
            //return arrayCT!ResType(ans);
            
            //ResType res = [ans[0], ans[1]];
            
            import std.array : array;
            ResType res = a.array;
            return res;
            /*
            ResType res;
            import std.algorithm : copy;
            copy(a, res[]);
            return res;
            */
            
            
        })(ans);
    }
    else
    {
        return ans;
    }
}
pure nothrow @nogc
{

    auto minByElem(bool convert = true, Arrays...)(Arrays arrays)
        if (allSatisfy!(isStaticArray, Arrays) && hasCommonElementType!Arrays)
    {
        import std.algorithm : min;
        return arrays.dive!(min, convert);
    }

    auto maxByElem(bool convert = true, Arrays...)(Arrays arrays)
        if (allSatisfy!(isStaticArray, Arrays) && hasCommonElementType!Arrays)
    {
        import std.algorithm : max;
        return arrays.dive!(max, convert);
    }
}

import std.traits : isFunctionPointer, isDelegate;
// Lie about `pure nothrow @nogc`
private auto assumeNoGC(T) (T t) pure nothrow @nogc if (isFunctionPointer!T || isDelegate!T)
{
    import std.traits : functionAttributes, FunctionAttribute, SetFunctionAttributes, functionLinkage;
    enum attrs = functionAttributes!T | FunctionAttribute.pure_ | FunctionAttribute.nothrow_ | FunctionAttribute.nogc;
    return cast(SetFunctionAttributes!(T, functionLinkage!T, attrs)) t;
}

// Canditate for inclusion in `std.traits`
private
{
    import std.traits;
    enum bool isImmutable(T) = is(ImmutableOf!T == T);
    enum bool isConst(T) = is(const(T) == T);

    template CommonQualifiers(alias F, T...)
    {
        static if (allSatisfy!(isImmutable, T))
        {
            alias CommonQualifiers = immutable(F!T);
        }
        else
        {
            static if (!anySatisfy!(isMutable, T))
            {
                static if (anySatisfy!(isConst, T))
                {
                    alias CommonQualifiers = const(F!T);
                }
                else
                {
                    alias CommonQualifiers = F!T;
                }
            }
            else
            {
                alias CommonQualifiers = F!T;
            }
        }
    }
}

void main()
{
    import std.stdio;
    static immutable int[2] a = [1, 4];
    static immutable int[4] b = [5, 1, 2, 3];
    static immutable real[3] c = [1.2, 3.4, 5.6];
    auto d = maxByElem(a, b, c);
    pragma(msg, d);
    import std.array : array;
    
    import std.algorithm : min;
    static immutable real[2] wut = dive!(min, false)(a, b, c).array;
    pragma(msg, wut);
    /*
    immutable real[2] wat = wut.array;
    
    pragma(msg, wat);
    //pragma(msg, wut);
    import std.array : join;
    //real[2] wat = mixin("[" ~ demux(0, typeof(wut).length, "wut").join(", ") ~ "]");
    import std.traits;
    pragma(msg, CommonArrayType!(typeof(a), typeof(b), typeof(c)));
    */
}
