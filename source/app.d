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
        alias CommonElementType = ElementType!(T[0]);
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

static string atorMix(string target = "arrays", Arrays...)() pure @property
{
    import std.array : join;
    return demux(0, Arrays.length, target, "[]").join(", ");
}

static string[] loopMix(size_t begin = 0, size_t end = 1, string form)()
{
    string[] lines;
    foreach (i; begin..end)
    {
        import std.array : replace;
        import std.conv : to;
        lines ~= form.replace("@", i.to!string);
    }
    return lines;
}

auto dive(alias fun, Arrays...)(Arrays arrays) pure nothrow @nogc
{
    import std.algorithm : reduce, map;
    import std.range : zip;
    auto ans = mixin("zip(" ~ atorMix!("arrays", Arrays) ~ ")").map!(reduce!fun);
    
    alias ResType = CommonElementType!Arrays[Shortest!Arrays.length];
    
    return ans;
}
pure nothrow @nogc
{
    auto minByElem(Arrays...)(Arrays arrays)
        if (allSatisfy!(isStaticArray, Arrays) && hasCommonElementType!Arrays)
    {
        import std.algorithm : min;
        return arrays.dive!(min);
    }

    auto maxByElem(Arrays...)(Arrays arrays)
        if (allSatisfy!(isStaticArray, Arrays) && hasCommonElementType!Arrays)
    {
        import std.algorithm : max;
        return arrays.dive!(max);
    }
    /*
    auto dot(Arrays...)(Arrays arrays) if (allSatisfy!(isStaticArray, Arrays))
    {
        import std.algorithm : reduce;
        import std.range : zip;
        import std.conv : to;
        import std.array : join;
        
        alias ElemType = Unqual!(CommonElementType!Arrays);
        ElemType res = 0;
        
        import std.format : format;
        // CTFE `zip`
        mixin(loopMix!(0, Shortest!Arrays.length, "res += %s;".format(demux(0, Arrays.length, "arrays", "[@]").join(" * "))).join("\n"));
        return res;
    }
    */
    
    import std.range : isInputRange;
    auto dot(A, B)(A a, B b) if (allSatisfy!(isInputRange, A, B))
    {
        import std.algorithm : map, sum;
        import std.range : zip;
        alias ResType = CommonElementType!(A, B);
        ResType res = zip(a, b).map!(c => c[0] * c[1]).sum;
        return res;
    }
    
    auto cross(A, B)(A a, B b) if (allSatisfy!(isStaticArray, A, B) && A.length == 3 && B.length == 3 && hasCommonArrayType!(A, B))
    {
        CommonArrayType!(A, B) res = [a[1] * b[2] - a[2] * b[1],
                                      a[2] * b[0] - a[0] * b[2],
                                      a[0] * b[1] - a[1] * b[0]];
        return res;
    }
    
    auto reflect(A, B)(A a, B b) if (allSatisfy!(isInputRange, A, B))
    {
        import std.algorithm : map;
        import std.range : zip;
        auto d = dot(a, b);
        auto res = zip(a, b).map!(c => c[0] - 2 * c[1] * d);
        return res;
    }
}

// Canditate for inclusion in `std.traits`
private
{
    import std.traits;
    enum bool isImmutable(T) = is(ImmutableOf!T == T);
    enum bool isConst(T) = is(ConstOf!T == T);

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
    import std.array : array;
    immutable int[3] a = [1, 4, 5];
    immutable real[3] b = [1.2, 3.4, 5.6];
    immutable auto d = reflect(a[], b[]).array;
    // TODO: Make `d` readable during compile time
    writeln(d);
}
