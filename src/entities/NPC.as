package entities 
{
	import net.flashpunk.*;
	import net.flashpunk.graphics.*;
	import flash.geom.Point;
	import utility.*;
	import worlds.Game;
	
	/**
	 * ...
	 * @author dolgion
	 */
	public class NPC extends Entity
	{
		public const NONE:int = 0;
		public const WALK:int = 1;
		
		public const MIN_DISTANCE:Number = 10;
		public const SPAWN_END:int = 2;
		
		[Embed(source = "../../assets/gfx/npc_01.png")] private var NPC_SPRITESHEET_01:Class;
		[Embed(source = "../../assets/gfx/npc_02.png")] private var NPC_SPRITESHEET_02:Class;
		
		public var spritesheets:Array = new Array(NPC_SPRITESHEET_01, NPC_SPRITESHEET_02);
		public const SPRITE_WIDTH:int = 25;
		public const SPRITE_HEIGHT:int = 29;
		
		public var spritesheetIndex:int;
		public var npcSpritemap:Spritemap;
		public var curAnimation:String = "walk_down";
		public var speed:int = 1;
		public var currentMapIndex:int;
		public var name:String;
		
		public var currentActivity:Number = NONE;
		public var path:Array = new Array();
		public var pathIndex:int;
		public var pathfinder:Pathfinder = new Pathfinder();
		public var mapPathfinder:MapPathfinder = new MapPathfinder();
		public var mapPath:Array = new Array();
		public var mapPathIndex:int;
	 	public var maps:Array;
		public var justSpawned:Boolean = false;
		public var endPoint:GlobalPosition;
		public var appointments:Array = new Array();
		
		public function NPC(_maps:Array, 
							_name:String, 
							_spritesheetIndex:int, 
							_x:int, 
							_y:int, 
							_mapIndex:int, 
							_appointments:Array)
		{
			maps = _maps;
			name = _name;
			x = _x;
			y = _y;
			currentMapIndex = _mapIndex;
			appointments = _appointments;
			
			spritesheetIndex = _spritesheetIndex;
			setupSpritesheet();
			graphic = npcSpritemap;
			npcSpritemap.play(curAnimation);
			setHitbox(SPRITE_WIDTH, SPRITE_HEIGHT, 0, 0);
			type = "npc"
		}
		
		override public function update():void
		{
			if (currentMapIndex != Game.currentMapIndex)
			{
				collidable = false;
				visible = false;
			}
			else 
			{
				collidable = true;
				visible = true;
			}
			npcSpritemap.play(curAnimation);
			
			if (currentActivity == WALK)
			{
				walkProcedure();
			}
		}
		
		public function walkProcedure():void
		{
			var distance:Number = FP.distance(x, y, path[pathIndex].x, path[pathIndex].y);
			if (distance < MIN_DISTANCE) 
			{
				pathIndex++;
				if (justSpawned && (collide("player", x, y) == null))
				{
					justSpawned = false;
				}
				if (pathIndex >= path.length)
				{
					pathIndex = 0;
					
					if (mapPathIndex == (mapPath.length - 1))
					{
						// then we're in the last map
						path = pathfinder.pathfinding(new GlobalPosition(currentMapIndex, x, y), endPoint, maps);
						if (path.length == 0)
						{
							// we finally arrived
							currentActivity = NONE;
							switch (curAnimation)
							{
								case "walk_left": curAnimation = "stand_left"; break;
								case "walk_right": curAnimation = "stand_right"; break;
								case "walk_up": curAnimation = "stand_up"; break;
								case "walk_down": curAnimation = "stand_down"; break;
							}
						}
						
						// for temporary ghost state
						justSpawned = true;
					}
					else
					{
						// change the current map index
						currentMapIndex = mapPath[++mapPathIndex];
						
						// determine the new starting position
						var startingPoint:Point = mapPathfinder.determineNewStartingPosition(maps, mapPath, mapPathIndex, x, y);
						x = startingPoint.x;
						y = startingPoint.y;
						
						// find the next exit point and set the path
						var exitPoint:GlobalPosition = mapPathfinder.findNextExitPoint(maps, mapPath, mapPathIndex, x, y, endPoint);
						path = pathfinder.pathfinding(new GlobalPosition(currentMapIndex, x, y), exitPoint, maps);
						
						// for temporary ghost state
						justSpawned = true;
					}
				}
			}
			else
			{
				movement();
			}
		}
		
		public function movement():void
		{
			var _x:int = x;
			var _y:int = y;
			var horizontalMovement:Boolean = true;
			var verticalMovement:Boolean = true;
			
			if (x < path[pathIndex].x)
			{
				curAnimation = "walk_right";
				x += speed;
			}
			else if (x > path[pathIndex].x)
			{
				curAnimation = "walk_left";
				x -= speed;
			}
			else horizontalMovement = false;
			
			
			if (y < path[pathIndex].y)
			{
				curAnimation = "walk_down";
				y += speed;
			}
			else if (y > path[pathIndex].y)
			{
				curAnimation = "walk_up";
				y -= speed;
			}
			else verticalMovement = false;
			
			if ((!verticalMovement) && (!horizontalMovement))
			{
				switch (curAnimation)
				{
					case "walk_left": trace("stand left now"); curAnimation = "stand_left"; break;
					case "walk_right": curAnimation = "stand_right"; break;
					case "walk_up": curAnimation = "stand_up"; break;
					case "walk_down": curAnimation = "stand_down"; break;
				}
			}
			
			if (!justSpawned)
			{
				if (colliding())					
				{
					x = _x;
					y = _y;
				}
			}
		}
		
		public function aiUpdate(hours:int, minutes:int):void
		{
			var appointment:Appointment;
			for each (appointment in appointments)
			{
				if ((appointment.hour == hours) && (appointment.minute == minutes))
				{
					moveToGlobalPosition(appointment.position);
				}
			}
		}
		
		public function moveToGlobalPosition(position:GlobalPosition):void
		{
			// set the global end point
			endPoint = position;
			
			// determine the map path
			mapPath = mapPathfinder.pathfinding(maps, currentMapIndex, endPoint.mapIndex);
			mapPathIndex = 0;

			// determine the immediate target point
			var exitPoint:GlobalPosition = mapPathfinder.findNextExitPoint(maps, mapPath, mapPathIndex, x, y, endPoint);
			path = pathfinder.pathfinding(new GlobalPosition(currentMapIndex, x, y), exitPoint, maps);
			
			// when all is okay, get the walking procedure going
			if ((path != null) && (path.length > 1))
			{
				currentActivity = WALK;
				pathIndex = 0;
			}
		}
		
		public function colliding():Boolean
		{
			if (collide("player", x, y)) return true;
			else return false;
		}
		
		public function setupSpritesheet():void
		{
			npcSpritemap = new Spritemap(spritesheets[spritesheetIndex], SPRITE_WIDTH, SPRITE_HEIGHT);
			npcSpritemap.add("walk_down", [0, 1], 5, true);
			npcSpritemap.add("walk_up", [2, 3], 5, true);
			npcSpritemap.add("walk_left", [4, 5], 5, true);
			npcSpritemap.add("walk_right", [6, 7], 5, true);
			npcSpritemap.add("stand_down", [0], 0, false);
			npcSpritemap.add("stand_up", [2], 0, false);
			npcSpritemap.add("stand_left", [4], 0, false);
			npcSpritemap.add("stand_right", [6], 0, false);
		}
	}

}