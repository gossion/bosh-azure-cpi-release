RSpec.describe "Making it yield arguments" do
  it "yields the provided args" do
    dbl = double
    allow(dbl).to receive(:foo).and_yield(2, 3)

    x = y = nil
    dbl.foo { |a, b| x, y = a, b }
    expect(x).to eq(2)
    expect(y).to eq(3)
  end
end
