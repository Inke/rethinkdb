$LOAD_PATH.unshift('./lib')
require 'rubygems'
require 'pp'
require 'ql2.pb.rb'
require 'socket'

def to_termtype sym
  eval "Term2::TermType::#{sym.to_s.upcase}"
end

def check pred
  raise RuntimeError, "CHECK FAILED" if not pred
end

$socket = TCPSocket.open('localhost', 60616)
$socket.send([0xaf61ba35].pack('L<'), 0)

def nativize_datum d
  dt = Datum::DatumType
  case d.type
  when dt::R_NUM then d.r_num
  when dt::R_STR then d.r_str
  when dt::R_BOOL then d.r_bool
  when dt::R_NULL then nil
  when dt::R_ARRAY then d.r_array.map{|d2| nativize_datum d2}
  when dt::R_OBJECT then Hash[d.r_object.map{|x| [x.key, nativize_datum(x.val)]}]
  else raise RuntimeError, "Unimplemented."
  end
end

def nativize_response r
  rt = Response2::ResponseType
  case r.type
  when rt::SUCCESS_ATOM then nativize_datum(r.response[0])
  when rt::SUCCESS_SEQUENCE then r.response.map{|d| nativize_datum(d)}
  when rt::RUNTIME_ERROR then
    raise RuntimeError, "#{r.response[0].r_str}
Backtrace: #{r.backtrace.map{|x| x.pos || x.opt}.inspect}"
  when rt::COMPILE_ERROR then # TODO: remove?
    raise RuntimeError, "#{r.response[0].r_str}
Backtrace: #{r.backtrace.map{|x| x.pos || x.opt}.inspect}"
  else r
  end
end

class RQL
  attr_accessor :is_r
  def initialize(term=nil)
    @term = term
    @is_r = !term
  end
  def method_missing(m, *a, &b)
    t = Term2.new
    t.type = to_termtype(m)
    t.args << self.to_term if !@is_r
    a.each {|arg| t.args << r(arg).to_term}
    return RQL.new t
  end
  def to_term
    check @term
    @term
  end

  @@token_cnt = 0
  @@socket = $socket

  def to_query
    q = Query2.new
    q.type = Query2::QueryType::START
    q.query = self.to_term
    q.token = @@token_cnt += 1
    return q
  end
  def run
    q = to_query
    payload = q.serialize_to_string
    packet = [payload.length].pack('L<') + payload
    @@socket.send(packet, 0)
    rlen = @@socket.read(4).unpack('L<')[0]
    r = @@socket.read(rlen)
    return nativize_response(Response2.new.parse_from_string(r))
  end

  def opt(key, val)
    ap = Term2::AssocPair.new
    ap.key = key.to_s
    ap.val = r(val).to_term
    self.to_term.optargs << ap
    return self
  end
end

def datum x
  dt = Datum::DatumType
  d = Datum.new
  return x if x.class == Datum
  case x.class.hash
  when Fixnum.hash then d.type = dt::R_NUM; d.r_num = x
  when Float.hash then d.type = dt::R_NUM; d.r_num = x
  when String.hash then d.type = dt::R_STR; d.r_str = x
  when Symbol.hash then d.type = dt::R_STR; d.r_str = x.to_s
  when TrueClass.hash then d.type = dt::R_BOOL; d.r_bool = x
  when FalseClass.hash then d.type = dt::R_BOOL; d.r_bool = x
  when NilClass.hash then d.type = dt::R_NULL
  when Array.hash then d.type = dt::R_ARRAY; d.r_array = x.map {|x| datum x}
  when Hash.hash then d.type = dt::R_OBJECT; d.r_object = x.map { |k,v|
      ap = Datum::AssocPair.new; ap.key = k.to_s; ap.val = datum v; ap }
  else raise RuntimeError, "Unimplemented."
  end
  return d
end

# Hash.hash

def r(a='8d19cb41-ddb8-44ab-92f3-f48ca607ab7b')
  return RQL.new if a == '8d19cb41-ddb8-44ab-92f3-f48ca607ab7b'
  return a if a.class == RQL
  d = datum(a)
  t = Term2.new
  t.type = Term2::TermType::DATUM
  t.datum = d
  return RQL.new t
end

$tests = 0
def assert_equal(a, b)
  raise RuntimeError, "#{a.inspect} != #{b.inspect}" if a != b
  $tests += 1
end

def assert_raise
  begin
    res = yield
  rescue Exception => e
  end
  raise RuntimeError, "Got #{res.inspect} instead of raise." if res
end

def rae(a, b)
  assert_equal(a.run, b)
end

rae(r(1), 1)
rae(r(2.0), 2.0)
rae(r("3"), "3")
rae(r(true), true)
rae(r(false), false)
rae(r(nil), nil)
rae(r([1, 2.0, "3", true, false, nil]), [1, 2.0, "3", true, false, nil])
rae(r({"abc" => 2.0, "def" => nil}), {"abc" => 2.0, "def" => nil})
rae(r.eq(1, 1), true)
rae(r.eq(1, 2), false)
rae(r.add(1, 2, 3, -1, 0.2), 5.2)
rae(r.sub(1, 2, 3), -4.0)
rae(r.mul(2, 3, 2, 0.5), 6.0)
rae(r.div(1, 2, 3), 1.0/6.0)
rae(r.div(1, 6), r.div(1, 2, 3).run)
rae(r.div(0.2), 0.2)
assert_raise{r.div(1, 0).run}
assert_raise{r.db('test').table('test2').run}

tbl = tst = r.db('test').table('test')
rae(tst.map(r.func([1], r.var(1))), tst.run)
rae(tst.map(r.func([1], 2)), tst.run.map{|x| 2})
rae(r([1,2,3]).map(r.func([1], r.mul(r.var(1), r.var(1), 2))), [2.0, 8.0, 18.0])
assert_raise{r([1,2,3]).map(r.func([1], r.mul(r.var(1), r.var(2), 2))).run}
assert_raise{r([1,2,3]).map(r.func([1], 2)).map(2).run}
rae(r([1,2,3]).map(r.func([1], r.var(1).mul(2))).map(r.func([1], r.var(1).add(1))),
    [3.0, 5.0, 7.0])

rae(r([1,2,3]).map(r.func([1], r.implicit_var.mul(r.var(1)))), [1.0, 4.0, 9.0])
assert_raise{r([1,2,3]).map(r.func([1], r([2,4]).map(r.func([2], r.implicit_var.mul(r.var(1)))))).run}
assert_raise{r.implicit_var.run}

rae(tbl.get(0), {"id"=>0.0})
rae(tbl.get(1), {"id"=>1.0})
rae(tbl.get(-1), nil)

rae(r(5).mod(3), 2)
assert_raise{r(5.2).mod(3).run}
assert_raise{r(5).mod(0).run}

rae(r([1,2,3]).append(4).append(5), [1.0, 2.0, 3.0, 4.0, 5.0])
assert_raise{r(1).append(2).run}

rae(r([1,2,3]).slice(0,0), [1.0])
rae(r([1,2,3]).slice(0,1), [1.0, 2.0])
rae(r([1,2,3]).slice(0,2), [1.0, 2.0, 3.0])
assert_raise{r([1,2,3]).slice(0,3).run}

rae(r([1,2,3]).slice(0,-1), [1.0, 2.0, 3.0])
rae(r([1,2,3]).slice(0,-2), [1.0, 2.0])
rae(r([1,2,3]).slice(0,-3), [1.0])
assert_raise{r([1,2,3]).slice(0,-4).run}

rae(tbl.slice(0,0), [{"id"=>0.0}])
rae(tbl.slice(0,1), [{"id"=>0.0}, {"id"=>1.0}])
rae(tbl.slice(0,-1), [{"id"=>0.0}, {"id"=>1.0}])
rae(tbl.slice(10,-1), [])

rae(r({'a' => 1, 'b' => 2}).getattr('a'), 1)
rae(r({'a' => 1, 'b' => 2}).getattr('b'), 2)
assert_raise{r({'a' => 1, 'b' => 2}).getattr('c').run}
rae(r({:a => 1, :b => 2}).contains(:a), true)
rae(r({:a => 1, :b => 2}).contains(:b), true)
rae(r({:a => 1, :b => 2}).contains(:c), false)

rae(r({:a => 1, :b => 2, :c => 3}).pluck(:a), {'a' => 1})
rae(r({:a => 1, :b => 2, :c => 3}).pluck(:a, :b), {'a' => 1, 'b' => 2})
rae(r({:a => 1, :b => 2, :c => 3}).pluck(:a, :b, :d), {'a' => 1, 'b' => 2})
rae(r([{:a => 1, :b => 2, :c => 3}]).pluck(:a), [{'a' => 1}])
rae(r([{:a => 1, :b => 2, :c => 3}]).pluck(:a, :b), [{'a' => 1, 'b' => 2}])
rae(r([{:a => 1, :b => 2, :c => 3}]).pluck(:a, :b, :d), [{'a' => 1, 'b' => 2}])
rae(r([{:a => 1, :b => 2, :c => 3}, {:d => 4}]).pluck(:a),
    [{'a' => 1}, {}])
rae(r([{:a => 1, :b => 2, :c => 3}, {:d => 4}]).pluck(:a, :b),
    [{'a' => 1, 'b' => 2}, {}])
rae(r([{:a => 1, :b => 2, :c => 3}, {:d => 4}]).pluck(:a, :b, :d),
    [{'a' => 1, 'b' => 2}, {'d' => 4}])
rae(tbl.pluck(:id), tbl.run)
rae(tbl.pluck(:dfjklsdf), [{}, {}])

rae(r({:a => 1, :b => 2, :c => 3}).without(:a), {"c"=>3.0, "b"=>2.0})
rae(r({:a => 1, :b => 2, :c => 3}).without(:a, :b), {"c"=>3.0})
rae(r({:a => 1, :b => 2, :c => 3}).without(:a, :b, :d), {"c"=>3.0})
rae(r([{:a => 1, :b => 2, :c => 3}]).without(:a), [{"c"=>3.0, "b"=>2.0}])
rae(r([{:a => 1, :b => 2, :c => 3}]).without(:a, :b), [{"c"=>3.0}])
rae(r([{:a => 1, :b => 2, :c => 3}]).without(:a, :b, :d), [{"c"=>3.0}])
rae(r([{:a => 1, :b => 2, :c => 3}, {:d => 4}]).without(:a),
    [{"c"=>3.0, "b"=>2.0}, {"d"=>4.0}])
rae(r([{:a => 1, :b => 2, :c => 3}, {:d => 4}]).without(:a, :b),
    [{"c"=>3.0}, {"d"=>4.0}])
rae(r([{:a => 1, :b => 2, :c => 3}, {:d => 4}]).without(:a, :b, :d),
    [{"c"=>3.0}, {}])
rae(tbl.without(:id), [{}, {}])
rae(tbl.without(:dfjklsdf), tbl.run)

rae(r({:a => 1, :b => 2}).merge({:b => 3, :c => 4}), {"c"=>4.0, "b"=>3.0, "a"=>1.0})

rae(r([1,2,3,4,5]).filter(r.func([1], r.var(1).eq(2))), [2.0])
rae(r([1,2,3,4,5]).filter(r.func([1], r.var(1).lt(4))), [1.0, 2.0, 3.0])

rae(tbl.filter(r.func([1], r.var(1).getattr(:id).eq(0))), [{"id"=>0.0}])
rae(tbl.filter(r.func([1], r.var(1).getattr(:id).eq(1))), [{"id"=>1.0}])
rae(tbl.filter(r.func([1], r.var(1).getattr(:id).lt(2))), [{"id"=>0.0}, {"id"=>1.0}])

rae(r.all(1, false, 3), false)
rae(r.all(1, 2, 3), 3)

rae(tbl.between.opt(:left_bound, 0), tbl.run)
rae(tbl.between.opt(:left_bound, -1).opt(:right_bound, 1), tbl.run)
rae(tbl.between.opt(:left_bound, 0).opt(:right_bound, 1), tbl.run)
rae(tbl.between.opt(:left_bound, 0).opt(:right_bound, 2), tbl.run)
rae(tbl.between.opt(:right_bound, 1), tbl.run)
rae(tbl.between.opt(:left_bound, 0).opt(:right_bound, 0), [{"id"=>0.0}])
rae(tbl.between.opt(:right_bound, 0), [{"id"=>0.0}])

rae(r.any(1, 2, 3), 1.0)
rae(r.any(nil, 2, 3), 2.0)
rae(r.any(nil, false, 3), 3.0)
rae(r.any(nil, false, nil), false)

rae(r.branch(true, 1, 2), 1.0)
rae(r.branch(false, 1, 2), 2.0)
rae(r.branch(1, 1, 2), 1.0)

rae(r([1,2,3,4,5]).reduce(r.func([1, 2], 1)), 1)
rae(r([1,2,3,4,5]).reduce(r.func([1, 2], r.var(1))), 1)
rae(r([1,2,3,4,5]).reduce(r.func([1, 2], r.var(2))), 5)
rae(r([1,2,3,4,5]).reduce(r.func([1, 2], r.var(1))).opt(:base, 10), 10)
rae(r([1,2,3,4,5]).reduce(r.func([1, 2], r.var(2))).opt(:base, 10), 5)
rae(r([1,2,3,4,5]).reduce(r.func([1, 2], r.add(r.var(1), r.var(2)))), 15)
rae(r([1,2,3,4,5]).reduce(r.func([1, 2], r.add(r.var(1), r.var(2)))).opt(:base, 1), 16)

tblids = tbl.map(r.func([1], r.var(1).getattr(:id)))
addfn = r.func([1, 2], r.var(1).add(r.var(2)))
rae(tblids.reduce(addfn), 1)
rae(tblids.map(r.func([1], r.add(r.var(1), 2))).reduce(addfn), 5)
rae(tblids.map(r.func([1], r.add(r.var(1), 2))).reduce(r.func([1, 2], 3)), 3)
assert_raise{tblids.map(r.func([1], r.add(r.var(1), 2))).reduce(r.func([1], 3)).run}
rae(tblids.reduce(addfn).opt(:base, 0), 1)
rae(tblids.reduce(addfn).opt(:base, 2), 3)

rae(r([1,2,3,4,5]).concatmap(r.func([1], r.make_array(r.var(1), r.var(1)))),
    [1.0, 1.0, 2.0, 2.0, 3.0, 3.0, 4.0, 4.0, 5.0, 5.0])

rae(tbl.concatmap(r.func([1], r.make_array(r.var(1), r.var(1)))),
    [{"id"=>0.0}, {"id"=>0.0}, {"id"=>1.0}, {"id"=>1.0}])

lst = r([{:id => 0, :a => 1}, {:id => 1, :a => 1}, {:id => 2, :a => 0}])
rae(lst.orderby([:id]), lst.run)
rae(lst.orderby([:a]),
    [{"a"=>0.0, "id"=>2.0}, {"a"=>1.0, "id"=>0.0}, {"a"=>1.0, "id"=>1.0}])
rae(lst.orderby([:a, '-id']),
    [{"a"=>0.0, "id"=>2.0}, {"a"=>1.0, "id"=>1.0}, {"a"=>1.0, "id"=>0.0}])

rae(r([1, 2, 3, 1, 2, 4, 1, 4, 5]).distinct, [1.0, 2.0, 3.0, 4.0, 5.0])

rae(tbl.count, 2)
rae(r([1,2,3]).count, 3)

rae(r.union(tbl.union(tbl).union([1,2,3]).union(tbl).union([]), tbl, tbl),
    [{"id"=>0.0}, {"id"=>1.0}, {"id"=>0.0}, {"id"=>1.0}, 1.0, 2.0, 3.0, {"id"=>0.0}, {"id"=>1.0}, {"id"=>0.0}, {"id"=>1.0}, {"id"=>0.0}, {"id"=>1.0}])

rae(r([1]).union([2]).union([3, 4], [5]).slice(-3, -1), [3, 4, 5])
rae(r([1]).union([2]).union([3, 4], [5]).slice(-3, -1).nth(1), 4)
rae(tbl.nth(0), {'id' => 0})
rae(tbl.nth(1), {'id' => 1})
assert_raise{tbl.nth(2).run}
assert_raise{tbl.nth(-1).run}

$gmr_data = r([{:a => 1, :b => 2, :c => 3},
               {:a => 2, :b => 1, :c => 40},
               {:a => 2, :b => 2, :c => 500},
               {:a => 3, :b => 1, :c => 6000}]);

rae($gmr_data.grouped_map_reduce(r.func([1], r.var(1).getattr(:a)),
                                 r.func([2], r.var(2).getattr(:c)),
                                 r.func([3, 4], r.var(3).add(r.var(4)))),
    [{"group"=>1.0, "reduction"=>3.0},
     {"group"=>2.0, "reduction"=>540.0},
     {"group"=>3.0, "reduction"=>6000.0}])


rae(tbl.grouped_map_reduce(r.func([1], r.var(1).getattr(:id)),
                           r.func([2], r.var(2).getattr(:id).add(10)),
                           r.func([3, 4], r.var(3).add(r.var(4)))),
    [{"group"=>0.0, "reduction"=>10.0}, {"group"=>1.0, "reduction"=>11.0}])

rae(tbl.grouped_map_reduce(r.func([1], 1),
                           r.func([2], r.var(2).getattr(:id).add(10)),
                           r.func([3, 4], r.var(3).add(r.var(4)))),
    [{"group"=>1.0, "reduction"=>21.0}])

####

print "test.test: #{r.db('test').table('test').run.inspect}\n"
print "Ran #{$tests} tests!\n"

####
