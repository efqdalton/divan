require "#{File.dirname(__FILE__)}/../test_helper.rb"

class InvalidatedModel < Divan::Models::ProofOfConcept
  before_validate :indiferent_callback
  after_validate  lambda{ |obj| obj != nil }
  after_validate  :invalidate

  def indiferent_callback
    true
  end
  
  def invalidate
    false
  end
end

class ViewedModel < Divan::Models::ProofOfConcept
  view_by :value
  view_by :mod
end

class ProofOfConcept < Divan::Models::ProofOfConcept
  property :first_name
end

class TestDivan < Test::Unit::TestCase
  def test_dynamic_model
    m = Divan::Model(:teste)
    assert m.class, Divan::Models::Teste
    assert m.database.name,     'test'
    assert m.database.host,     '127.0.0.1'
    assert m.database.port,     12345
    assert m.database.user,     'admin'
    assert m.database.password, 'top1secret2pass'
  end

  def test_get_database_stats
    database = Divan[:proof_of_concept]
    assert_equal database.stats[:db_name], 'proof_of_concept'
  end

  def test_create_and_delete_database
    database = Divan::Database.new :created_test_database, 'host' => 'http://127.0.0.1', 'database' => 'test_database'
    delete_lambda = lambda{
      assert database.delete['ok']
      assert !database.exists?
    }
    create_lambda = lambda{
      assert database.create['ok']
      assert_equal database.stats[:db_name], 'test_database'
    }
    delete_lambda.call if database.exists?
    create_lambda.call
    delete_lambda.call
  end

  def test_database_not_found
    database = Divan::Database.new :missing_database, 'host' => 'http://localhost', 'database' => 'mising_database'
    assert_raise(Divan::DatabaseNotFound){ database.stats }
    assert_raise(Divan::DatabaseNotFound){ database.delete }
  end

  def test_database_already_created
    database = Divan::Database.new :already_created, 'host' => 'http://localhost', 'database' => 'already_created'
    assert database.create['ok']
    assert_raise(Divan::DatabaseAlreadyCreated){ database.create }
    assert database.delete['ok'] # Only to ensure that database is deleted after this test
  end

  def test_saving_and_retrieving_simple_document_should_work
    object = ProofOfConcept.new :simple_param  => 'Working well!',
                                :hashed_params => { :is_a => 'Hash', :hash_size => 2 }
    assert object.save
    retrieved_object = ProofOfConcept.find object.id
    assert retrieved_object
    assert retrieved_object.rev
    assert_equal object.id, retrieved_object.id
    assert_equal object.attributes, retrieved_object.attributes
    assert retrieved_object.delete['ok']
    assert_not_equal object.rev, retrieved_object.rev
  end

  def test_retrieving_non_existent_document_should_return_nil
    obj = ProofOfConcept.find '0'*32 # Probably this uuid don't exists in database
    assert_nil obj
  end  

  def test_updating_document
    object = ProofOfConcept.new
    object[:hashed_params] = {:is_a => 'Hash', :hash_size => 2}
    object[:simple_param]  = 'Working well!'
    assert object.save
    retrieved_object = ProofOfConcept.find object.id
    assert retrieved_object
    retrieved_object[:updated_attrib] = 'New attribute!'
    assert retrieved_object.save['ok']
    object[:lost_race] = 'I\'ll fail!'
    assert_raise(Divan::DocumentConflict){ object.save }
  end

  def test_retrieving_deleted_object
    object = ProofOfConcept.new
    object[:hashed_params] = {:is_a => 'Hash', :hash_size => 2}
    object[:simple_param]  = 'Working well!'
    assert object.save
    assert object.delete
    retrieved_object = ProofOfConcept.find object.id
    assert_nil retrieved_object
  end

  def test_deleting_document_twice
    object = ProofOfConcept.new
    object[:hashed_params] = {:is_a => 'Hash', :hash_size => 2}
    object[:simple_param]  = 'Working well!'
    assert object.save
    assert object.delete
    assert_nil object.delete
  end

  def test_save_deleted_document
    object = ProofOfConcept.new
    object[:hashed_params] = {:is_a => 'Hash', :hash_size => 2}
    object[:simple_param]  = 'Working well!'
    assert object.save
    assert object.delete
    assert object.save
    assert object.delete
  end

  def test_delete_all_from_database
    assert ProofOfConcept.delete_all
    10.times do |n|
      assert ProofOfConcept.new( :value => n ).save
    end
    assert Divan[:proof_of_concept].create_views
    assert_equal ProofOfConcept.delete_all(:limit => 6), 6
    assert_equal ProofOfConcept.all.first.class, ProofOfConcept
    assert_equal ProofOfConcept.delete_all, 4
    assert ProofOfConcept.find('_design/proof_of_concept')
    assert_equal ProofOfConcept.all.count, 0
  end

  def test_bulk_create
    assert ProofOfConcept.delete_all
    params = 10.times.map do |n|
      {:number => n, :double => 2*n}
    end
    assert ProofOfConcept.create params
    assert_equal ProofOfConcept.delete_all, 10
  end

  def test_perform_view_by_query
    assert ViewedModel.delete_all
    assert Divan[:proof_of_concept].create_views
    params = 10.times.map do |n|
      {:mod => (n%2), :value => "#{n} mod 2"}
    end
    assert ViewedModel.create params
    obj = ViewedModel.by_value '5 mod 2'
    assert obj
    assert_equal obj.mod, 1
    assert_equal ViewedModel.all_by_mod(0).count, 5
    assert_equal ViewedModel.find_all.count, 10
    assert_equal ViewedModel.delete_all, 10
  end

  def test_before_validate_callback_avoids_save
    object = InvalidatedModel.new
    assert !object.save
    assert_nil object.rev
  end

  def test_dynamic_access_to_attributes
    object = ProofOfConcept.new :dynamic_attribute => 'Working'
    assert object.dynamic_attribute, 'Working'
    assert_equal( (object.dynamic_setter = "Well"), 'Well')
    assert_equal object.dynamic_setter, 'Well'
  end

  def test_setting_properties
    object = ProofOfConcept.new
    assert_nil object.first_name
    assert_raise(NoMethodError){ object.last_name }
  end

  def test_top_level_model
    Divan::Models::ProofOfConcept.delete_all
    ProofOfConcept.create :test => 123
    Divan::Models::ProofOfConcept.create :test => 456
    ViewedModel.create :test => 789
    assert_equal Divan::Models::ProofOfConcept.find_all.count, 3
    assert_equal ProofOfConcept.find_all.count, 3
    assert_equal ViewedModel.find_all.count, 1
    assert_equal ViewedModel.delete_all, 1
    assert_equal ProofOfConcept.delete_all, 2
  end

  def test_first_wins_save_strategy
    first = ProofOfConcept.create :test => 123
    last  = ProofOfConcept.new :id => first.id, :test => 321
    assert last.save(:first_wins)
    assert_equal ProofOfConcept.find(first.id).test, 123
    assert_equal last.test, 123
  end

  def test_last_wins_save_strategy
    first = ProofOfConcept.create :test => 123
    last  = ProofOfConcept.new :id => first.id, :test => 321
    assert last.save(:last_wins)
    assert_equal ProofOfConcept.find(first.id).test, 321
    assert_equal last.test, 321
  end

  def test_merge_save_strategy
    first = ProofOfConcept.create :test_one => 1, :test => 'Working'
    last  = ProofOfConcept.new :id => first.id, :test_one => 123, :test_two => 321
    expected_attributes = first.attributes.merge last.attributes
    assert last.save(:merge)
    assert_equal ProofOfConcept.find(first.id).attributes, expected_attributes
    assert_equal last.attributes, expected_attributes
  end

  def test_custom_save_strategy
    first = ProofOfConcept.create :amount => 100
    last  = ProofOfConcept.new :id => first.id, :amount => 200
    expected_attributes = first.attributes.merge last.attributes
    assert last.save(){ |here, in_database| here.amount += in_database.amount }
    assert_equal ProofOfConcept.find(first.id).amount, 300
    assert_equal last.amount, 300
    assert first.save(){ |here, in_database| here.amount > in_database.amount }
    assert_equal ProofOfConcept.find(first.id).amount, 300
    assert_equal first.amount, 300
  end
end
