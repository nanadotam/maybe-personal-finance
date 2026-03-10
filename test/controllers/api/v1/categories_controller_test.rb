# frozen_string_literal: true

require "test_helper"

class Api::V1::CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @category = categories(:food_and_drink)
    @subcategory = categories(:subcategory)

    @other_family_user = users(:family_member)
    @other_family_user.update!(family: families(:empty))

    @user.api_keys.active.destroy_all

    @api_key = ApiKey.create!(
      user: @user,
      name: "Categories Read-Write Key",
      scopes: [ "read_write" ],
      display_key: "test_categories_rw_#{SecureRandom.hex(8)}"
    )

    @read_only_api_key = ApiKey.create!(
      user: @user,
      name: "Categories Read-Only Key",
      scopes: [ "read" ],
      display_key: "test_categories_ro_#{SecureRandom.hex(8)}",
      source: "mobile"
    )

    Redis.new.del("api_rate_limit:#{@api_key.id}")
    Redis.new.del("api_rate_limit:#{@read_only_api_key.id}")
  end

  test "should require authentication" do
    get api_v1_categories_url

    assert_response :unauthorized
    response_body = JSON.parse(response.body)
    assert_equal "unauthorized", response_body["error"]
  end

  test "should list categories for the current family" do
    get api_v1_categories_url, headers: api_headers(@api_key)

    assert_response :success
    response_body = JSON.parse(response.body)

    assert response_body.key?("categories")
    assert response_body.key?("pagination")
    assert response_body["categories"].any? { |category| category["id"] == @category.id }
    assert response_body["categories"].all? { |category| @family.categories.exists?(id: category["id"]) }
  end

  test "should allow read-only api key access" do
    get api_v1_categories_url, headers: api_headers(@read_only_api_key)

    assert_response :success
  end

  test "should filter categories by classification" do
    get api_v1_categories_url,
        params: { classification: "expense" },
        headers: api_headers(@api_key)

    assert_response :success
    response_body = JSON.parse(response.body)

    assert response_body["categories"].all? { |category| category["classification"] == "expense" }
  end

  test "should filter root categories" do
    get api_v1_categories_url,
        params: { roots: true },
        headers: api_headers(@api_key)

    assert_response :success
    response_body = JSON.parse(response.body)

    assert response_body["categories"].all? { |category| category["parent_id"].nil? }
    assert response_body["categories"].any? { |category| category["id"] == @category.id }
    assert response_body["categories"].none? { |category| category["id"] == @subcategory.id }
  end

  test "should search categories by name" do
    get api_v1_categories_url,
        params: { search: "Food" },
        headers: api_headers(@api_key)

    assert_response :success
    response_body = JSON.parse(response.body)

    assert response_body["categories"].any? { |category| category["id"] == @category.id }
    assert response_body["categories"].none? { |category| category["id"] == @subcategory.id }
  end

  test "should show a category with lookup fields" do
    get api_v1_category_url(@subcategory), headers: api_headers(@api_key)

    assert_response :success
    response_body = JSON.parse(response.body)

    assert_equal @subcategory.id, response_body["id"]
    assert_equal "Restaurants", response_body["name"]
    assert_equal @category.id, response_body["parent_id"]
    assert_equal "Food & Drink / Restaurants", response_body["path"]
    assert_equal @category.id, response_body.dig("parent", "id")
    assert_equal @category.name, response_body.dig("parent", "name")
  end

  test "should return 404 for a category outside the current family" do
    other_family_category = categories(:one)

    get api_v1_category_url(other_family_category), headers: api_headers(@api_key)

    assert_response :not_found
  end

  test "should return 404 for a missing category" do
    get api_v1_category_url("00000000-0000-0000-0000-000000000000"), headers: api_headers(@api_key)

    assert_response :not_found
  end
end
