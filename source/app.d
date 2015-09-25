import std.range : ElementType, hasLength;
import std.traits : CommonType, isArray, isStaticArray;
import std.typetuple : staticMap, allSatisfy;

template CommonElementType(T...) if (allSatisfy!(hasLength, T))
{
    static if (T.length == 1)
    {
        alias CommonElementType = T[0];
    }
    else static if (T.length >= 2)
    {
        alias CommonElementType = CommonType!(staticMap!(ElementType, T));
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
        alias CommonArrayType = CommonElementType!T[length];
    }
    else static if (allSatisfy!(isArray, T))
    {
        alias CommonArrayType = CommonElementType!T[];
    }
    else
    {
        alias CommonArrayType = void;
    }
}

/**
Same as std.traits.Largest, but for length.
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
    import std.typecons : tuple;
    import std.array : join;
    return demux(0, Arrays.length, target, "[]").join(", ");
}

auto dive(alias fun, bool convert = true, Arrays...)(ref Arrays arrays) pure nothrow @nogc
{
    import std.algorithm : reduce, map;
    import std.range : zip;
    auto ans = mixin("zip(" ~ atorMix!("arrays", Arrays) ~ ")").map!(reduce!fun);
    static if (convert)
    {
        return assumeNoGC((typeof(ans) a)
        {
            alias ResType = CommonElementType!Arrays[Shortest!Arrays.length];
            ResType res;
            import std.algorithm : copy;
            copy(a, res[]);
            return res;
        })(ans);
    }
    else
    {
        return ans;
    }
}
pure nothrow @nogc
{

    auto minByElem(bool convert = true, Arrays...)(ref Arrays arrays)
        if (allSatisfy!(isStaticArray, Arrays) && hasCommonElementType!Arrays)
    {
        import std.algorithm : min;
        return arrays.dive!(min, convert);
    }

    auto maxByElem(bool convert = true, Arrays...)(ref Arrays arrays)
        if (allSatisfy!(isStaticArray, Arrays) && hasCommonElementType!Arrays)
    {
        import std.algorithm : max;
        return arrays.dive!(max, convert);
    }
}

import std.traits : isFunctionPointer, isDelegate;
// Lie about `pure nothrow @nogc`
private auto assumeNoGC(T) (T t) if (isFunctionPointer!T || isDelegate!T)
{
    import std.traits : functionAttributes, FunctionAttribute, SetFunctionAttributes, functionLinkage;
    enum attrs = functionAttributes!T | FunctionAttribute.pure_ | FunctionAttribute.nothrow_ | FunctionAttribute.nogc;
    return cast(SetFunctionAttributes!(T, functionLinkage!T, attrs)) t;
}

void main()
{
    import std.stdio;
    int[2] a = [1, 4];
    int[4] b = [5, 1, 2, 3];
    real[3] c = [1.2, 3.4, 5.6];
    //writeln(maxByElem(a, b, c));
}
