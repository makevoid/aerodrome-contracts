# Aerodrome Contracts Deployment Rakefile
require 'time'
require 'json'

desc "Display available tasks"
task :default do
  puts "Available tasks:"
  puts "  rake deploy:router   - Deploy UniversalRouter (Aerodrome Router) to Anvil"
  puts "  rake deploy:core     - Deploy core contracts to Anvil"
  puts "  rake deploy:all      - Deploy all contracts to Anvil"
  puts "  rake setup:swap      - Deploy tokens (A,B,C), create pools (A-B, A-C, C-B), and add liquidity for multi-route testing"
  puts "  rake swap:execute    - Execute a test swap"
  puts "  rake check:router    - Check if Router is deployed on Anvil"
  puts "  rake check:swap      - Check swap setup status"
  puts "  rake clean           - Clean build artifacts"
end

namespace :deploy do
  desc "Deploy UniversalRouter (Aerodrome Router) to Anvil"
  task :router do
    puts "🚀 Deploying UniversalRouter (Aerodrome Router) to Anvil..."

    # Check if Anvil is running
    unless system("curl -s -X POST -H 'Content-Type: application/json' --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}' http://localhost:8545 > /dev/null")
      puts "❌ Anvil is not running. Start it manually: anvil"
      exit 1
    end

    # Create anvil constants file
    create_anvil_constants

    # Deploy using forge script
    env_vars = {
      'CONSTANTS_FILENAME' => 'Anvil.json',
      'OUTPUT_FILENAME' => 'Anvil.json',
      'PRIVATE_KEY_DEPLOY' => '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80' # First anvil account
    }

    cmd = env_vars.map { |k, v| "#{k}=#{v}" }.join(' ')
    cmd += " forge script script/DeployCore.s.sol:DeployCore --rpc-url http://localhost:8545 --broadcast --via-ir"

    if system(cmd)
      puts "✅ Router deployed successfully!"

      # Extract Router address from broadcast file
      broadcast_file = "broadcast/DeployCore.s.sol/31337/run-latest.json"
      if File.exist?(broadcast_file)
        broadcast = JSON.parse(File.read(broadcast_file))
        router_tx = broadcast['transactions'].find { |tx| tx['contractName'] == 'Router' }

        if router_tx
          router_address = router_tx['contractAddress']
          puts "📍 Router deployed at: #{router_address}"

          # Save deployment info
          deployment_info = {
            'router' => router_address,
            'deployed_at' => Time.now.iso8601,
            'chain_id' => 31337,
            'rpc_url' => 'http://localhost:8545'
          }
          File.write('anvil_deployment.json', JSON.pretty_generate(deployment_info))
          puts "💾 Deployment info saved to anvil_deployment.json"
        end
      end
    else
      puts "❌ Router deployment failed"
      exit 1
    end
  end

  desc "Deploy core contracts to Anvil"
  task :core => :router do
    puts "✅ Core contracts deployment completed (includes Router)"
  end

  desc "Deploy all contracts to Anvil"
  task :all => :core do
    puts "🚀 Deploying additional contracts..."

    # Deploy governors
    env_vars = {
      'CONSTANTS_FILENAME' => 'Anvil.json',
      'OUTPUT_FILENAME' => 'Anvil.json',
      'PRIVATE_KEY_DEPLOY' => '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'
    }

    cmd = env_vars.map { |k, v| "#{k}=#{v}" }.join(' ')
    cmd += " forge script script/DeployGovernors.s.sol:DeployGovernors --rpc-url http://localhost:8545 --broadcast --via-ir"

    if system(cmd)
      puts "✅ All contracts deployed successfully!"
    else
      puts "⚠️  Some additional contracts failed to deploy, but core functionality is available"
    end
  end
end

namespace :check do
  desc "Check if Router is deployed on Anvil"
  task :router do
    puts "🔍 Checking Router deployment on Anvil..."

    unless system("curl -s http://localhost:8545 > /dev/null")
      puts "❌ Anvil is not running on http://localhost:8545"
      exit 1
    end

    if File.exist?('anvil_deployment.json')
      deployment = JSON.parse(File.read('anvil_deployment.json'))
      router_address = deployment['router']

      # Check if contract exists at address
      check_cmd = %{curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_getCode","params":["#{router_address}", "latest"],"id":1}' http://localhost:8545}
      result = `#{check_cmd}`

      if result.include?('"result":"0x"') || result.include?('"result":""')
        puts "❌ No contract found at Router address: #{router_address}"
        puts "💡 Run 'rake deploy:router' to deploy the Router"
      else
        puts "✅ Router contract found at: #{router_address}"
        puts "🌐 Chain ID: #{deployment['chain_id']}"
        puts "📅 Deployed at: #{deployment['deployed_at']}"

        # Get block number to confirm network is active
        block_result = `curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8545`
        if block_result.include?('"result"')
          block_hex = JSON.parse(block_result)['result']
          block_number = block_hex.to_i(16)
          puts "📦 Current block: #{block_number}"
        end
      end
    else
      puts "❌ No deployment info found"
      puts "💡 Run 'rake deploy:router' to deploy the Router"
    end
  end
end

desc "Clean build artifacts"
task :clean do
  puts "🧹 Cleaning build artifacts..."

  dirs_to_clean = ['out', 'cache', 'broadcast']
  dirs_to_clean.each do |dir|
    if Dir.exist?(dir)
      system("rm -rf #{dir}")
      puts "🗑️  Removed #{dir}/"
    end
  end

  files_to_clean = ['anvil_deployment.json']
  files_to_clean.each do |file|
    if File.exist?(file)
      File.delete(file)
      puts "🗑️  Removed #{file}"
    end
  end

  puts "✅ Clean completed"
end

namespace :setup do
  desc "Deploy tokens (A,B,C), create pools (A-B, A-C, C-B), and add liquidity for multi-route testing"
  task :swap do
    puts "🚀 Setting up multi-route swap environment..."

    # Check if Anvil is running
    unless system("curl -s -X POST -H 'Content-Type: application/json' --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}' http://localhost:8545 > /dev/null")
      puts "❌ Anvil is not running. Start it manually: anvil"
      exit 1
    end

    # Check if router is deployed
    unless File.exist?('anvil_deployment.json')
      puts "❌ Router not deployed. Run: rake deploy:router"
      exit 1
    end

    # Run setup script
    env_vars = {
      'PRIVATE_KEY_DEPLOY' => '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'
    }

    cmd = env_vars.map { |k, v| "#{k}=#{v}" }.join(' ')
    cmd += " forge script script/SetupSwap.s.sol:SetupSwap --rpc-url http://localhost:8545 --broadcast --unlocked"

    if system(cmd)
      puts "✅ Multi-route swap setup completed successfully!"

      if File.exist?('anvil_swap_setup.json')
        setup = JSON.parse(File.read('anvil_swap_setup.json'))
        puts "📍 TokenA: #{setup['tokenA']}"
        puts "📍 TokenB: #{setup['tokenB']}"
        puts "📍 TokenC: #{setup['tokenC']}"
        puts "📍 Pool A-B: #{setup['poolAB']}"
        puts "📍 Pool A-C: #{setup['poolAC']}"
        puts "📍 Pool C-B: #{setup['poolCB']}"
        puts "📍 Router: #{setup['router']}"
        puts ""
        puts "🔀 Multi-route setup: A -> C -> B routes are now available!"
      end
    else
      puts "❌ Swap setup failed"
      exit 1
    end
  end
end

namespace :swap do
  desc "Execute a test swap"
  task :execute do
    puts "🔄 Executing test swap..."

    # Check setup
    unless File.exist?('anvil_swap_setup.json')
      puts "❌ Swap not set up. Run: rake setup:swap"
      exit 1
    end

    # Check if Anvil is running
    unless system("curl -s -X POST -H 'Content-Type: application/json' --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}' http://localhost:8545 > /dev/null")
      puts "❌ Anvil is not running. Start it manually: anvil"
      exit 1
    end

    # Run swap script
    env_vars = {
      'PRIVATE_KEY_DEPLOY' => '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'
    }

    cmd = env_vars.map { |k, v| "#{k}=#{v}" }.join(' ')
    cmd += " forge script script/ExecuteSwap.s.sol:ExecuteSwap --rpc-url http://localhost:8545 --broadcast --unlocked"

    if system(cmd)
      puts "✅ Swap executed successfully!"
    else
      puts "❌ Swap failed"
      exit 1
    end
  end
end

namespace :check do
  desc "Check swap setup status"
  task :swap do
    puts "🔍 Checking swap setup..."

    if File.exist?('anvil_swap_setup.json')
      setup = JSON.parse(File.read('anvil_swap_setup.json'))

      puts "✅ Multi-route swap setup found:"
      puts "📍 TokenA: #{setup['tokenA']}"
      puts "📍 TokenB: #{setup['tokenB']}"
      puts "📍 TokenC: #{setup['tokenC']}"
      puts "📍 Pool A-B: #{setup['poolAB']}"
      puts "📍 Pool A-C: #{setup['poolAC']}"
      puts "📍 Pool C-B: #{setup['poolCB']}"
      puts "📍 Router: #{setup['router']}"

      # Check token balances
      deployer = setup['deployer']

      puts "\n💰 Token balances:"
      balance_a = `cast call #{setup['tokenA']} "balanceOf(address)(uint256)" #{deployer} --rpc-url http://localhost:8545`.strip
      balance_b = `cast call #{setup['tokenB']} "balanceOf(address)(uint256)" #{deployer} --rpc-url http://localhost:8545`.strip
      balance_c = `cast call #{setup['tokenC']} "balanceOf(address)(uint256)" #{deployer} --rpc-url http://localhost:8545`.strip

      puts "TokenA balance: #{balance_a}"
      puts "TokenB balance: #{balance_b}"
      puts "TokenC balance: #{balance_c}"
      puts ""
      puts "🔀 Available routes: A->B (direct), A->C->B (multi-hop)"
    else
      puts "❌ Swap setup not found"
      puts "💡 Run 'rake setup:swap' to set up multi-route swap environment"
    end
  end
end

# Helper method to create anvil constants
def create_anvil_constants
  constants_dir = 'script/constants'
  Dir.mkdir(constants_dir) unless Dir.exist?(constants_dir)

  # Create complete constants file for Anvil deployment
  anvil_constants = {
    "WETH" => "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", # Standard WETH address
    "allowedManager" => "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", # First anvil account
    "team" => "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
    "feeManager" => "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
    "emergencyCouncil" => "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
    "whitelistTokens" => [
      "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2" # WETH
    ],
    "pools" => [],
    "poolsAero" => [],
    "minter" => {
      "liquid" => [
        {
          "amount" => 50000000000000000000000000,
          "wallet" => "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
        }
      ],
      "locked" => [
        {
          "amount" => 100000000000000000000000000,
          "wallet" => "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
        }
      ]
    }
  }

  File.write("#{constants_dir}/Anvil.json", JSON.pretty_generate(anvil_constants))
  puts "📝 Created Anvil constants file"
end
