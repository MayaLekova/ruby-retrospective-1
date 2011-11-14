require 'bigdecimal'
require 'bigdecimal/util'

class BigDecimal
  def to_2f()
    sprintf "%.2f", to_s('F')
  end
  
  def to_price()
    to_2f.rjust(8)
  end
end

class String
  def to_title()
    ljust(48)
  end
end

class Cart
  def initialize(inventory)
    @order = Hash.new(0)
    @products = inventory.products
    @promos = inventory.promos
    @coupons = inventory.coupons
  end
  
  def add(name, quantity = 1)
    if !@products.has_key? name or !(@order[name] + quantity).between?(1, 99)
      raise "Invalid parameters passed."
    end
    @order[name] += quantity
  end
  
  def raw_total
    @order.map { |name, quantity| 
      @promos[name].total(quantity, @products[name].to_d) }.inject :+
  end
  
  def total
    raw_total + (@used_coupon ? @used_coupon.discount(raw_total) : 0)
  end
  
  def invoice
    @@line + @@header + @@line +
      (@order.keys.map { |v| entry_to_s v }.inject :+) +
      (@used_coupon ? @used_coupon.coupon_to_s(raw_total) : "") +
      @@line + footer + @@line
  end
  
  def use(name)
    @used_coupon = Coupon.new(name, @coupons[name])
  end
  
  @@line = "+------------------------------------------------+----------+\n"
  @@header = "| Name                                       qty |    price |\n"
  
  def raw_price(name)
    @products[name].to_d * @order[name]
  end
  
  def footer
    "| TOTAL                                          | " +
      total.to_price + " |\n"
  end
  
  def entry_to_s(name)
    "| " + name + @order[name].to_s.rjust(46 - name.length) + " | " + 
      raw_price(name).to_price + " |\n" +
      @promos[name].promo_to_s(@order[name], @products[name].to_d)
  end
end

class Coupon
  def initialize(name, spec)
    @name = name
    if spec.keys[0] == :percent
      @percent = spec.values[0]
    elsif spec.keys[0] == :amount
      @amount = spec.values[0]
    end
  end
  
  def coupon_to_s(price)
    ("| Coupon " + @name + " - " + discount_to_s + " off").to_title +
      " | " + discount(price).to_price + " |\n"
  end
  
  def discount_to_s
    if @percent
      @percent.to_s + "%"
    elsif @amount
      @amount.to_s
    else
      ""
    end
  end
  
  def discount(price)
    if @percent
      -price * @percent / BigDecimal("100.0")
    elsif @amount
      -(@amount.to_d)
    else
      0
    end
  end
end

class Promo
  def total(quantity, price)
    quantity * price + discount(quantity, price)
  end  
  
  def promo_to_s(quantity, price)
    ""
  end
end

class StandardPrice < Promo
  def discount(quantity, price)
    0
  end
end

class GetOneFree < Promo
  def initialize(count)
    @count = count
  end
  
  def discount(quantity, price)
    -(quantity / @count) * price
  end

  def promo_to_s(quantity, price)
    ("|   (buy " + (count - 1).to_s + ", get 1 free)").to_title + " | " + 
      discount(quantity, price).to_price + " |\n"
  end    
  
  attr_reader :count
end

class Package < Promo
  def initialize(spec)
    @count, @percent = spec.keys[0], spec.values[0]
  end
  
  def discount(quantity, price)
    -((quantity / @count) * @count * @percent * price) / BigDecimal("100.0")
  end

  def promo_to_s(quantity, price)
    ("|   (get " + @percent.to_s + "% off for every " + @count.to_s + ")").to_title + 
      " | " + discount(quantity, price).to_price + " |\n"
  end
  
  attr_reader :count, :percent
end

class Threshold < Promo
  def initialize(spec)
    @count, @percent = spec.keys[0], spec.values[0]
  end
  
  def discount(quantity, price)
    if quantity <= count
      return BigDecimal.new("0")
    end
    
    -((quantity - count) * price * @percent) / BigDecimal("100.0")
  end

  def promo_to_s(quantity, price)
    descr = "% off of every after the "
    ("|   (" + @percent.to_s + descr + count_to_s + ")").to_title + 
      " | " + discount(quantity, price).to_price + " |\n"
  end
  
  def count_to_s
    if count == 1
      "1st"
    elsif count == 2
      "2nd"
    elsif count == 3
      "3rd"
    else
      @count.to_s + "th"
    end
  end

  attr_reader :count, :percent
end

class Inventory
  def initialize()
    @products = {}
    @promos = {}
    @coupons = {}
  end
  
  attr_reader :products, :promos, :coupons
  
  def register(name, price, promo = {})
    if name.length > 40 or !price.to_d.between?(0.01, 999.99) or @products.has_key? name
      raise "Invalid parameters passed."
    end
    
    @products[name] = price
    
    handle_promos promo, name
  end
  
  def handle_promos(promo, name)
    if promo.has_key? :get_one_free
      @promos[name] = GetOneFree.new(promo[:get_one_free])
    elsif promo.has_key? :package
      @promos[name] = Package.new(promo[:package])
    elsif promo.has_key? :threshold
      @promos[name] = Threshold.new(promo[:threshold])
    else
      @promos[name] = StandardPrice.new
    end
  end
  
  def register_coupon(name, spec)
    @coupons[name] = spec
  end
  
  def new_cart
    return Cart.new(self)
  end
  
end
