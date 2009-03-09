require 'active_wmi/connection'
require 'cgi'
require 'set'

module ActiveWmi
  # ActiveWmi::Base is the main class for mapping Windows WMI resources as models in a Rails application.
  # == Automated mapping
  #
  # Active WMI objects represent your WMI resources as manipulatable Ruby objects.  To map resources
  # to Ruby objects, Active WMI only needs a class name that corresponds to the resource name and a 
  # +site+ value, which holds the address of the resources.
  #
  #   class Person < ActiveResource::Base
  #     self.site = "winmgts:\\\\testserver.test.com\\root\\sms\\site_100"
  #   end
  #
  # Now the Person class is mapped to WMI resources located at <tt>http://api.people.com:3000/people/</tt>, and
  # you can now use Active Wmi's lifecycles methods to manipulate resources. In the case where you already have
  # an existing model with the same name as the desired Wmi resource you can set the +element_name+ value.
  #
  #   class PersonResource < ActiveResource::Base
  #     self.site = "http://api.people.com:3000/"
  #     self.element_name = "person"
  #   end
  #
  #
  # == Lifecycle methods
  #
  # Active WMI exposes methods for creating, finding, updating, and deleting resources
  # from WMI.
  #
  #   ryan = Person.new(:first => 'Ryan', :last => 'Daigle')
  #   ryan.save                # => true
  #   ryan.id                  # => 2
  #   Person.exists?(ryan.id)  # => true
  #   ryan.exists?             # => true
  #
  #   ryan = Person.find(1)
  #   # Resource holding our newly created Person object
  #
  #   ryan.first = 'Rizzle'
  #   ryan.save                # => true
  #
  #   ryan.destroy             # => true
  #
  # As you can see, these are very similar to Active Record's lifecycle methods for database records.
  # You can read more about each of these methods in their respective documentation.
  #
  # === Custom REST methods
  #
  # Since simple CRUD/lifecycle methods can't accomplish every task, Active Resource also supports
  # defining your own custom REST methods. To invoke them, Active Resource provides the <tt>get</tt>,
  # <tt>post</tt>, <tt>put</tt> and <tt>\delete</tt> methods where you can specify a custom REST method
  # name to invoke.
  #
  #   # POST to the custom 'register' REST method, i.e. POST /people/new/register.xml.
  #   Person.new(:name => 'Ryan').post(:register)
  #   # => { :id => 1, :name => 'Ryan', :position => 'Clerk' }
  #
  #   # PUT an update by invoking the 'promote' REST method, i.e. PUT /people/1/promote.xml?position=Manager.
  #   Person.find(1).put(:promote, :position => 'Manager')
  #   # => { :id => 1, :name => 'Ryan', :position => 'Manager' }
  #
  #   # GET all the positions available, i.e. GET /people/positions.xml.
  #   Person.get(:positions)
  #   # => [{:name => 'Manager'}, {:name => 'Clerk'}]
  #
  #   # DELETE to 'fire' a person, i.e. DELETE /people/1/fire.xml.
  #   Person.find(1).delete(:fire)
  #
  #
  # == Validations
  #
  # See the ActiveResource::Validations documentation for more information.
  #
  # == Authentication
  #
  # Many WMI resources will require authentication.  Authentication 
  # can be specified by:
  # * defining +user+ and/or +password+ variables
  #
  #    class Person < ActiveWmi::Base
  #      self.site = "winmgts:\\\\oldtas247\\root\\sms\\site_100"
  #      self.user = "ryan"
  #      self.password = "password"
  #    end
  #
  # == Errors & Validation
  #
  # Error handling and validation is handled in much the same manner as you're used to seeing in
  # Active Record.  
  #
  # === Resource errors
  #
  # INCOMPLETE
  #
  # === Validation errors
  #
  # Active Wmi supports validations on resources and will return errors if any these validations fail
  # (e.g., "First name can not be blank" and so on).  These types of errors are denoted in the response by
  # a response code of <tt>422</tt> and an XML representation of the validation errors.  The save operation will
  # then fail (with a <tt>false</tt> return value) and the validation errors can be accessed on the resource in question.
  #
  #   ryan = Person.find(1)
  #   ryan.first # => ''
  #   ryan.save  # => false
  #   ryan.errors.invalid?(:first)  # => true
  #   ryan.errors.full_messages     # => ['First cannot be empty']
  #
  # Learn more about Active Resource's validation features in the ActiveResource::Validations documentation.
  #
  # === Timeouts
  #
  # INCOMPLETE
  
  class Base
    # The logger for diagnosing and tracing Active WMI calls.
    cattr_accessor :logger

    class << self
      # Gets the address of the WMI Server to connect for this class.  The site variable is required for
      # Active Wmi's mapping to work.
      def site
        # Not using superclass_delegating_reader because don't want subclasses to modify superclass instance
        #
        # With superclass_delegating_reader
        #
        #   Parent.site = 'http://anonymous@test.com'
        #   Subclass.site # => 'http://anonymous@test.com'
        #   Subclass.site.user = 'david'
        #   Parent.site # => 'http://david@test.com'
        #
        # Without superclass_delegating_reader (expected behaviour)
        #
        #   Parent.site = 'http://anonymous@test.com'
        #   Subclass.site # => 'http://anonymous@test.com'
        #   Subclass.site.user = 'david' # => TypeError: can't modify frozen object
        #
        if defined?(@site)
          @site
        elsif superclass != Object && superclass.site
          superclass.site.dup.freeze
        end
      end

      # Sets the address of the WMI resources to map for this class to the value in the +site+ argument.
      # The site variable is required for Active WMI's mapping to work.
      def site=(site)
        @connection = nil
        if site.nil?
          @site = nil
        else
          @site = site
        end
      end

      # Gets the \user for OLE authentication.
      def user
        # Not using superclass_delegating_reader. See +site+ for explanation
        if defined?(@user)
          @user
        elsif superclass != Object && superclass.user
          superclass.user.dup.freeze
        end
      end

      # Sets the \user for OLE authentication.
      def user=(user)
        @connection = nil
        @user = user
      end

      # Gets the \password for OLE authentication.
      def password
        # Not using superclass_delegating_reader. See +site+ for explanation
        if defined?(@password)
          @password
        elsif superclass != Object && superclass.password
          superclass.password.dup.freeze
        end
      end

      # Sets the \password for OLE authentication.
      def password=(password)
        @connection = nil
        @password = password
      end

      # Sets the number of seconds after which requests to the OLE interface should time out.
      # INCOMPLETE - timeout currently has no effect
      def timeout=(timeout)
        @connection = nil
        @timeout = timeout
      end

      # Gets the number of seconds after which requests to the OLE interface should time out.
      def timeout
        if defined?(@timeout)
          @timeout
        elsif superclass != Object && superclass.timeout
          superclass.timeout
        end
      end

      # An instance of ActiveWmi::Connection that is the base \connection to the remote service.
      # The +refresh+ parameter toggles whether or not the \connection is refreshed at every request
      # or not (defaults to <tt>false</tt>).
      def connection(refresh = false)
        if defined?(@connection) || superclass == Object
          @connection = Connection.new(site) if refresh || @connection.nil?
          @connection.user = user if user
          @connection.password = password if password
          @connection.timeout = timeout if timeout
          @connection
        else
          superclass.connection
        end
      end

      # Do not include any modules in the default element name. This makes it easier to seclude AWmi objects
      # in a separate namespace without having to set element_name repeatedly.
      attr_accessor_with_default(:element_name)    { to_s.split("::").last.underscore } #:nodoc:

      attr_accessor_with_default(:collection_name) { element_name.pluralize } #:nodoc:
      attr_accessor_with_default(:primary_key, 'id') #:nodoc:
      
      
      alias_method :set_element_name, :element_name=  #:nodoc:
      alias_method :set_collection_name, :collection_name=  #:nodoc:

      # INCOMPLETE - How do you path out an item in this language?
      # Gets the element path for the given ID in +id+.  If the +query_options+ parameter is omitted, Rails
      # will split from the \prefix options.
      #
      # ==== Options
      # +prefix_options+ - A \hash to add a \prefix to the request for nested URLs (e.g., <tt>:account_id => 19</tt>
      #                    would yield a URL like <tt>/accounts/19/purchases.xml</tt>).
      # +query_options+ - A \hash to add items to the query string for the request.
      #
      # ==== Examples
      #   Post.element_path(1)
      #   # => /posts/1.xml
      #
      #   Comment.element_path(1, :post_id => 5)
      #   # => /posts/5/comments/1.xml
      #
      #   Comment.element_path(1, :post_id => 5, :active => 1)
      #   # => /posts/5/comments/1.xml?active=1
      #
      #   Comment.element_path(1, {:post_id => 5}, {:active => 1})
      #   # => /posts/5/comments/1.xml?active=1
      #
      def element_path(id, prefix_options = {}, query_options = nil)
        prefix_options, query_options = split_options(prefix_options) if query_options.nil?
        ":#{collection_name}.#{primary_key}#{id}"
      end

      # INCOMPLETE - How do you path this?
      # Gets the collection path for the REST resources.  If the +query_options+ parameter is omitted, Rails
      # will split from the +prefix_options+.
      #
      # ==== Options
      # * +prefix_options+ - A hash to add a prefix to the request for nested URL's (e.g., <tt>:account_id => 19</tt>
      #   would yield a URL like <tt>/accounts/19/purchases.xml</tt>).
      # * +query_options+ - A hash to add items to the query string for the request.
      #
      # ==== Examples
      #   Post.collection_path
      #   # => /posts.xml
      #
      #   Comment.collection_path(:post_id => 5)
      #   # => /posts/5/comments.xml
      #
      #   Comment.collection_path(:post_id => 5, :active => 1)
      #   # => /posts/5/comments.xml?active=1
      #
      #   Comment.collection_path({:post_id => 5}, {:active => 1})
      #   # => /posts/5/comments.xml?active=1
      #
      def collection_path(query_options = nil)
        query = query_string(query_options)
        query = (query && query != "") ? (" where " + query) : String.new() 
        query = "SELECT * FROM #{element_name}" + query
        return query  
      end

      alias_method :set_primary_key, :primary_key=  #:nodoc:

      # Creates a new resource instance and makes a request to the remote service
      # that it be saved, making it equivalent to the following simultaneous calls:
      #
      #   ryan = Person.new(:first => 'ryan')
      #   ryan.save
      #
      # Returns the newly created resource.  If a failure has occurred an
      # exception will be raised (see <tt>save</tt>).  If the resource is invalid and
      # has not been saved then <tt>valid?</tt> will return <tt>false</tt>,
      # while <tt>new?</tt> will still return <tt>true</tt>.
      #
      # ==== Examples
      #   Person.create(:name => 'Jeremy', :email => 'myname@nospam.com', :enabled => true)
      #   my_person = Person.find(:first)
      #   my_person.email # => myname@nospam.com
      #
      #   dhh = Person.create(:name => 'David', :email => 'dhh@nospam.com', :enabled => true)
      #   dhh.valid? # => true
      #   dhh.new?   # => false
      #
      #   # We'll assume that there's a validation that requires the name attribute
      #   that_guy = Person.create(:name => '', :email => 'thatguy@nospam.com', :enabled => true)
      #   that_guy.valid? # => false
      #   that_guy.new?   # => true
      def create(attributes = {})
        returning(self.new(attributes)) { |res| res.save }
      end

      # Core method for finding resources.  Used similarly to Active Record's +find+ method.
      #
      # ==== Arguments
      # The first argument is considered to be the scope of the query.  That is, how many
      # resources are returned from the request.  It can be one of the following.
      #
      # * <tt>:one</tt> - Returns a single resource.
      # * <tt>:first</tt> - Returns the first resource found.
      # * <tt>:last</tt> - Returns the last resource found.
      # * <tt>:all</tt> - Returns every resource that matches the request.
      #
      # ==== Options
      #
      # * <tt>:from</tt> - Sets the path or custom method that resources will be fetched from.
      # * <tt>:params</tt> - Sets query and \prefix (nested URL) parameters.
      #
      # ==== Examples
      #   Person.find(1)
      #   # => GET /people/1.xml
      #
      #   Person.find(:all)
      #   # => GET /people.xml
      #
      #   Person.find(:all, :params => { :title => "CEO" })
      #   # => GET /people.xml?title=CEO
      #
      #   Person.find(:first, :from => :managers)
      #   # => GET /people/managers.xml
      #
      #   Person.find(:last, :from => :managers)
      #   # => GET /people/managers.xml
      #
      #   Person.find(:all, :from => "/companies/1/people.xml")
      #   # => GET /companies/1/people.xml
      #
      #   Person.find(:one, :from => :leader)
      #   # => GET /people/leader.xml
      #
      #   Person.find(:all, :from => :developers, :params => { :language => 'ruby' })
      #   # => GET /people/developers.xml?language=ruby
      #
      #   Person.find(:one, :from => "/companies/1/manager.xml")
      #   # => GET /companies/1/manager.xml
      #
      #   StreetAddress.find(1, :params => { :person_id => 1 })
      #   # => GET /people/1/street_addresses/1.xml
      def find(*arguments)
        scope   = arguments.slice!(0)
        options = arguments.slice!(0) || {}

        case scope
          when :all   then find_every(options)
          when :first then find_every(options).first
          when :last  then find_every(options).last
          when :one   then find_one(options)
          else             find_single(scope, options)
        end
      end

      # Deletes the resources with the ID in the +id+ parameter.
      #
      # ==== Options
      # All options specify \prefix and query parameters.
      #
      # ==== Examples
      #   Event.delete(2) # sends DELETE /events/2
      #
      #   Event.create(:name => 'Free Concert', :location => 'Community Center')
      #   my_event = Event.find(:first) # let's assume this is event with ID 7
      #   Event.delete(my_event.id) # sends DELETE /events/7
      #
      #   # Let's assume a request to events/5/cancel.xml
      #   Event.delete(params[:id]) # sends DELETE /events/5
      def delete(id, options = {})
        connection.delete(element_path(id, options))
      end

      # INCOMPLETE - What are the prefix and query options?
      # Asserts the existence of a resource, returning <tt>true</tt> if the resource is found.
      #
      # ==== Examples
      #   Note.create(:title => 'Hello, world.', :body => 'Nothing more for now...')
      #   Note.exists?(1) # => true
      #
      #   Note.exists(1349) # => false
      def exists?(id, options = {})
        if id
          prefix_options, query_options = split_options(options[:params])
          path = element_path(id, prefix_options, query_options)
          response = connection.head(path, headers)
          response.code.to_i == 200
        end
        # id && !find_single(id, options).nil?
      rescue ActiveResource::ResourceNotFound
        false
      end

      private
        # Find every resource
        def find_every(options)
          case from = options[:from]
          when Symbol
            instantiate_collection(get(from, options[:params]))
          when String
            path = "#{from}#{query_string(options[:params])}"
            instantiate_collection(connection.get(path, headers) || [])
          else
            query_options = options[:params]
            path = collection_path(query_options)
            instantiate_collection( (connection.find(path) || []))
          end
        end

        # Find a single resource from a one-off URL
        def find_one(options)
          case from = options[:from]
          when Symbol
            instantiate_record(get(from, options[:params]))
          when String
            path = "#{from}#{query_string(options[:params])}"
            instantiate_record(connection.get(path, headers))
          end
        end

        # INCOMPLETE - Test for options
        # Find a single resource from the default URL
        def find_single(scope, options)
          prefix_options, query_options = split_options(options[:params])
          path = element_path(scope, prefix_options, query_options)
          instantiate_record(connection.get(path, headers), prefix_options)
        end

        def instantiate_collection(collection)
          collection.collect! { |record| instantiate_record(record) }
        end

        
        def instantiate_record(record)
          return new(record)
        end
        
        # Builds the query string for the request.
        def query_string(options)
          return nil unless options
          query = String.new()
          options.each { |field, value|
            field = field.to_s if field.is_a?(Symbol)
            query = query + field + " = '" + value + "' & "
          }
          query = query.chop.chop.chop
          return query
        end

        # split an option hash into two hashes, one containing the prefix options,
        # and the other containing the leftovers.
        # INCOMPLETE - Haven't worked out the params format yet
        def split_options(options = {})
          prefix_options, query_options = {}, {}

          (options || {}).each do |key, value|
            next if key.blank?
            (prefix_parameters.include?(key.to_sym) ? prefix_options : query_options)[key.to_sym] = value
          end

          [ prefix_options, query_options ]
        end
    end

    attr_accessor :attributes #:nodoc:
    attr_accessor :prefix_options #:nodoc:

    # Constructor method for \new resources; the optional +attributes+ parameter takes a \hash
    # of attributes for the \new resource.
    #
    # ==== Examples
    #   my_course = Course.new
    #   my_course.name = "Western Civilization"
    #   my_course.lecturer = "Don Trotter"
    #   my_course.save
    #
    #   my_other_course = Course.new(:name => "Philosophy: Reason and Being", :lecturer => "Ralph Cling")
    #   my_other_course.save
    def initialize(new_item)
      @attributes = Hash.new()
      puts new_item.to_s
      load(new_item)
    end

    # Returns a \clone of the resource that hasn't been assigned an +id+ yet and
    # is treated as a \new resource.
    #
    #   ryan = Person.find(1)
    #   not_ryan = ryan.clone
    #   not_ryan.new?  # => true
    #
    # Any active resource member attributes will NOT be cloned, though all other
    # attributes are.  This is to prevent the conflict between any +prefix_options+
    # that refer to the original parent resource and the newly cloned parent
    # resource that does not exist.
    #
    #   ryan = Person.find(1)
    #   ryan.address = StreetAddress.find(1, :person_id => ryan.id)
    #   ryan.hash = {:not => "an ARes instance"}
    #
    #   not_ryan = ryan.clone
    #   not_ryan.new?            # => true
    #   not_ryan.address         # => NoMethodError
    #   not_ryan.hash            # => {:not => "an ARes instance"}
    def clone
      # Clone all attributes except the pk and any nested ActiveWmi
      cloned = attributes.reject {|k,v| k == self.class.primary_key || v.is_a?(ActiveWmi::Base)}.inject({}) do |attrs, (k, v)|
        attrs[k] = v.clone
        attrs
      end
      # Form the new resource - bypass initialize of resource with 'new' as that will call 'load' which
      # attempts to convert hashes into member objects and arrays into collections of objects.  We want
      # the raw objects to be cloned so we bypass load by directly setting the attributes hash.
      resource = self.class.new({})
      resource.prefix_options = self.prefix_options
      resource.send :instance_variable_set, '@attributes', cloned
      resource
    end


    # A method to determine if the resource a \new object (i.e., it has not been saved via OLE yet).
    #
    # ==== Examples
    #   not_new = Computer.create(:brand => 'Apple', :make => 'MacBook', :vendor => 'MacMall')
    #   not_new.new? # => false
    #
    #   is_new = Computer.new(:brand => 'IBM', :make => 'Thinkpad', :vendor => 'IBM')
    #   is_new.new? # => true
    #
    #   is_new.save
    #   is_new.new? # => false
    #
    def new?
      id.nil?
    end

    # Gets the <tt>\id</tt> attribute of the resource.
    def id
      attributes[self.class.primary_key]
    end

    # Sets the <tt>\id</tt> attribute of the resource.
    def id=(id)
      attributes[self.class.primary_key] = id
    end

    # Allows Active Resource objects to be used as parameters in Action Pack URL generation.
    def to_param
      id && id.to_s
    end

    # Test for equality.  Resource are equal if and only if +other+ is the same object or
    # is an instance of the same class, is not <tt>new?</tt>, and has the same +id+.
    #
    # ==== Examples
    #   ryan = Person.create(:name => 'Ryan')
    #   jamie = Person.create(:name => 'Jamie')
    #
    #   ryan == jamie
    #   # => false (Different name attribute and id)
    #
    #   ryan_again = Person.new(:name => 'Ryan')
    #   ryan == ryan_again
    #   # => false (ryan_again is new?)
    #
    #   ryans_clone = Person.create(:name => 'Ryan')
    #   ryan == ryans_clone
    #   # => false (Different id attributes)
    #
    #   ryans_twin = Person.find(ryan.id)
    #   ryan == ryans_twin
    #   # => true
    #
    def ==(other)
      other.equal?(self) || (other.instance_of?(self.class) && !other.new? && other.id == id)
    end

    # Tests for equality (delegates to ==).
    def eql?(other)
      self == other
    end

    # Delegates to id in order to allow two resources of the same type and \id to work with something like:
    #   [Person.find(1), Person.find(2)] & [Person.find(1), Person.find(4)] # => [Person.find(1)]
    def hash
      id.hash
    end

    # Duplicate the current resource without saving it.
    #
    # ==== Examples
    #   my_invoice = Invoice.create(:customer => 'That Company')
    #   next_invoice = my_invoice.dup
    #   next_invoice.new? # => true
    #
    #   next_invoice.save
    #   next_invoice == my_invoice # => false (different id attributes)
    #
    #   my_invoice.customer   # => That Company
    #   next_invoice.customer # => That Company
    def dup
      returning self.class.new do |resource|
        resource.attributes     = @attributes
        resource.prefix_options = @prefix_options
      end
    end

    # A method to \save (+POST+) or \update (+PUT+) a resource.  It delegates to +create+ if a \new object, 
    # +update+ if it is existing. If the response to the \save includes a body, it will be assumed that this body
    # is XML for the final object as it looked after the \save (which would include attributes like +created_at+
    # that weren't part of the original submit).
    #
    # ==== Examples
    #   my_company = Company.new(:name => 'RoleModel Software', :owner => 'Ken Auer', :size => 2)
    #   my_company.new? # => true
    #   my_company.save # sends POST /companies/ (create)
    #
    #   my_company.new? # => false
    #   my_company.size = 10
    #   my_company.save # sends PUT /companies/1 (update)
    def save
      new? ? create : update
    end

    # INCOMPLETE - Do I need Headers?
    # Deletes the resource from the remote service.
    #
    # ==== Examples
    #   my_id = 3
    #   my_person = Person.find(my_id)
    #   my_person.destroy
    #   Person.find(my_id) # 404 (Resource Not Found)
    #
    #   new_person = Person.create(:name => 'James')
    #   new_id = new_person.id # => 7
    #   new_person.destroy
    #   Person.find(new_id) # 404 (Resource Not Found)
    def destroy
      connection.delete(element_path, self.class.headers)
    end

    # Evaluates to <tt>true</tt> if this resource is not <tt>new?</tt> and is
    # found on the remote service.  Using this method, you can check for
    # resources that may have been deleted between the object's instantiation
    # and actions on it.
    #
    # ==== Examples
    #   Person.create(:name => 'Theodore Roosevelt')
    #   that_guy = Person.find(:first)
    #   that_guy.exists? # => true
    #
    #   that_lady = Person.new(:name => 'Paul Bean')
    #   that_lady.exists? # => false
    #
    #   guys_id = that_guy.id
    #   Person.delete(guys_id)
    #   that_guy.exists? # => false
    def exists?
      !new? && self.class.exists?(to_param, :params => prefix_options)
    end

    # A method to convert the the resource to an XML string.
    #
    # ==== Options
    # The +options+ parameter is handed off to the +to_xml+ method on each
    # attribute, so it has the same options as the +to_xml+ methods in
    # Active Support.
    #
    # * <tt>:indent</tt> - Set the indent level for the XML output (default is +2+).
    # * <tt>:dasherize</tt> - Boolean option to determine whether or not element names should
    #   replace underscores with dashes (default is <tt>false</tt>).
    # * <tt>:skip_instruct</tt> - Toggle skipping the +instruct!+ call on the XML builder
    #   that generates the XML declaration (default is <tt>false</tt>).
    #
    # ==== Examples
    #   my_group = SubsidiaryGroup.find(:first)
    #   my_group.to_xml
    #   # => <?xml version="1.0" encoding="UTF-8"?>
    #   #    <subsidiary_group> [...] </subsidiary_group>
    #
    #   my_group.to_xml(:dasherize => true)
    #   # => <?xml version="1.0" encoding="UTF-8"?>
    #   #    <subsidiary-group> [...] </subsidiary-group>
    #
    #   my_group.to_xml(:skip_instruct => true)
    #   # => <subsidiary_group> [...] </subsidiary_group>
    def to_xml(options={})
      attributes.to_xml({:root => self.class.element_name}.merge(options))
    end

    # Returns a JSON string representing the model. Some configuration is
    # available through +options+.
    #
    # ==== Options
    # The +options+ are passed to the +to_json+ method on each
    # attribute, so the same options as the +to_json+ methods in
    # Active Support.
    #
    # * <tt>:only</tt> - Only include the specified attribute or list of
    #   attributes in the serialized output. Attribute names must be specified
    #   as strings.
    # * <tt>:except</tt> - Do not include the specified attribute or list of
    #   attributes in the serialized output. Attribute names must be specified
    #   as strings.
    #
    # ==== Examples
    #   person = Person.new(:first_name => "Jim", :last_name => "Smith")
    #   person.to_json
    #   # => {"first_name": "Jim", "last_name": "Smith"}
    #
    #   person.to_json(:only => ["first_name"])
    #   # => {"first_name": "Jim"}
    #
    #   person.to_json(:except => ["first_name"])
    #   # => {"last_name": "Smith"}
    def to_json(options={})
      attributes.to_json(options)
    end

    # A method to \reload the attributes of this object from the remote web service.
    #
    # ==== Examples
    #   my_branch = Branch.find(:first)
    #   my_branch.name # => "Wislon Raod"
    #
    #   # Another client fixes the typo...
    #
    #   my_branch.name # => "Wislon Raod"
    #   my_branch.reload
    #   my_branch.name # => "Wilson Road"
    def reload
      self.load(self.class.find(to_param, :params => @prefix_options).attributes)
    end

    # A method to manually load attributes from a \hash. Recursively loads collections of
    # resources.  This method is called in +initialize+ and +create+ when a \hash of attributes
    # is provided.
    #
    # ==== Examples
    #   my_attrs = {:name => 'J&J Textiles', :industry => 'Cloth and textiles'}
    #   my_attrs = {:name => 'Marty', :colors => ["red", "green", "blue"]}
    #
    #   the_supplier = Supplier.find(:first)
    #   the_supplier.name # => 'J&M Textiles'
    #   the_supplier.load(my_attrs)
    #   the_supplier.name('J&J Textiles')
    #
    #   # These two calls are the same as Supplier.new(my_attrs)
    #   my_supplier = Supplier.new
    #   my_supplier.load(my_attrs)
    #
    #   # These three calls are the same as Supplier.create(my_attrs)
    #   your_supplier = Supplier.new
    #   your_supplier.load(my_attrs)
    #   your_supplier.save
    def load(object)
      if (object.is_a?(Hash))
        attributes = object
      else
        attributes = Hash.new()
        object.properties_.each do |property|
          attributes[property.name] = property.value
        end
      end
      attributes.each do |key, value|
        @attributes[key.to_s] =
          case value
            when Array
              resource = find_or_create_resource_for_collection(key)
              value.map { |attrs| attrs.is_a?(String) ? attrs.dup : resource.new(attrs) }
            when Hash
              resource = find_or_create_resource_for(key)
              resource.new(value)
            else
              value.dup rescue value
          end
      end
      self
    end

    # For checking <tt>respond_to?</tt> without searching the attributes (which is faster).
    alias_method :respond_to_without_attributes?, :respond_to?

    # A method to determine if an object responds to a message (e.g., a method call). In Active Resource, a Person object with a
    # +name+ attribute can answer <tt>true</tt> to <tt>my_person.respond_to?(:name)</tt>, <tt>my_person.respond_to?(:name=)</tt>, and
    # <tt>my_person.respond_to?(:name?)</tt>.
    def respond_to?(method, include_priv = false)
      method_name = method.to_s
      if attributes.nil?
        return super
      elsif attributes.has_key?(method_name)
        return true
      elsif ['?','='].include?(method_name.last) && attributes.has_key?(method_name.first(-1))
        return true
      end
      # super must be called at the end of the method, because the inherited respond_to?
      # would return true for generated readers, even if the attribute wasn't present
      super
    end


    protected
      def connection(refresh = false)
        self.class.connection(refresh)
      end

      # Update the resource on the remote service.
      # INCOMPLETE - Put is no longer the right command
      def update
        returning connection.put(element_path(prefix_options), encode, self.class.headers) do |response|
          load_attributes_from_response(response)
        end
      end

      # Create (i.e., \save to the remote service) the \new resource.
      # INCOMPLETE - post is no longer the orrect command
      def create
        returning connection.post(collection_path, encode, self.class.headers) do |response|
          self.id = id_from_response(response)
          load_attributes_from_response(response)
        end
      end

      #INCOMPLETE - Decode is the wrong command
      def load_attributes_from_response(response)
        load(response)
      end

      # Takes a response from a typical create post and pulls the ID out
      # INCOMPLETE - need a new mthod for getting an id
      def id_from_response(response)
        response['Location'][/\/([^\/]*?)(\.\w+)?$/, 1]
      end

      def element_path(options = nil)
        self.class.element_path(to_param, options || prefix_options)
      end

      def collection_path(options = nil)
        self.class.collection_path(options || prefix_options)
      end

    private
      # INCOMPLETE - Don't understand the next three methods
      # Tries to find a resource for a given collection name; if it fails, then the resource is created
      def find_or_create_resource_for_collection(name)
        find_or_create_resource_for(name.to_s.singularize)
      end

      # Tries to find a resource in a non empty list of nested modules
      # Raises a NameError if it was not found in any of the given nested modules
      def find_resource_in_modules(resource_name, module_names)
        receiver = Object
        namespaces = module_names[0, module_names.size-1].map do |module_name|
          receiver = receiver.const_get(module_name)
        end
        if namespace = namespaces.reverse.detect { |ns| ns.const_defined?(resource_name) }
          return namespace.const_get(resource_name)
        else
          raise NameError
        end
      end

      # Tries to find a resource for a given name; if it fails, then the resource is created
      def find_or_create_resource_for(name)
        resource_name = name.to_s.camelize
        ancestors = self.class.name.split("::")
        if ancestors.size > 1
          find_resource_in_modules(resource_name, ancestors)
        else
          self.class.const_get(resource_name)
        end
      rescue NameError
        if self.class.const_defined?(resource_name)
          resource = self.class.const_get(resource_name)
        else
          resource = self.class.const_set(resource_name, Class.new(ActiveWmi::Base))
        end
        resource.site   = self.class.site
        resource.password = self.class.password
        resource.user = self.class.user
      end

      def split_options(options = {})
        self.class.__send__(:split_options, options)
      end

      def method_missing(method_symbol, *arguments) #:nodoc:
        method_name = method_symbol.to_s

        case method_name.last
          when "="
            attributes[method_name.first(-1)] = arguments.first
          when "?"
            attributes[method_name.first(-1)]
          else
            attributes.has_key?(method_name) ? attributes[method_name] : super
        end
      end
  end
end